/*
    Procedimiento: sp_CerrarYAbrirEstadoCuenta

    Cierra el estado de cuenta correspondiente a la fecha indicada
    y abre el estado del siguiente periodo.

    Calcula intereses sobre el saldo minimo, comisiones por exceso
    de operaciones, multas por saldo minimo y cargos mensuales.
    Registra los movimientos correspondientes y actualiza los saldos.

    Las actualizaciones se realizan dentro de una transaccion.

    Codigos de resultado:
        0           Operacion exitosa.
        50300       Parametros invalidos.
        50301       La cuenta no existe.
        50302       No existe un unico estado para cerrar.
        50303       El periodo ya fue cerrado.
        50304       Contadores sin inicializar.
        50305       Los saldos no coinciden.
        50306       Faltan tipos de movimiento.
        50307       Saldo insuficiente para los cargos.
        50308       Ya existen movimientos del cierre.
        Otro        Error de SQL Server.

    Ejemplo de ejecucion (solo en una base de pruebas):

    DECLARE @Codigo INT;
    DECLARE @IdNuevoEstado INT;

    EXEC dbo.sp_CerrarYAbrirEstadoCuenta
        @inNumeroCuenta = 'NUMERO_CUENTA',
        @inFechaCierre = '2026-03-31',
        @outResultCode = @Codigo OUTPUT,
        @outIdNuevoEstadoCuenta = @IdNuevoEstado OUTPUT;

    SELECT
        @Codigo AS CodigoResultado,
        @IdNuevoEstado AS IdNuevoEstadoCuenta;

    -- Los valores del ejemplo deben adaptarse a una cuenta de prueba
    -- cuya fecha de cierre coincida con la indicada.
*/


USE CuentaAhorrosTP2;
GO
CREATE OR ALTER PROCEDURE dbo.sp_CerrarYAbrirEstadoCuenta
	@inNumeroCuenta VARCHAR(16),
	@inFechaCierre DATE,
	@outResultCode INT OUTPUT,
	@outIdNuevoEstadoCuenta INT OUTPUT
AS 
BEGIN
	SET NOCOUNT ON;

    DECLARE @IdCuenta INT;
    DECLARE @IdEstadoCuenta INT;
    DECLARE @CantidadEstados INT;
    DECLARE @FechaCreacion DATE;
    DECLARE @SaldoCuenta DECIMAL(18,2);
    DECLARE @SaldoPeriodo DECIMAL(18,2);
    DECLARE @SaldoMinimoPeriodo DECIMAL(18,2);
    DECLARE @SaldoMinimoFinal DECIMAL(18,2);
    DECLARE @SaldoTrabajo DECIMAL(18,2);
    DECLARE @TasaInteresAnual DECIMAL(5,2);
    DECLARE @SaldoMinimoRequerido DECIMAL(18,2);
    DECLARE @MultaSaldoMin DECIMAL(18,2);
    DECLARE @CargoMensual DECIMAL(18,2);
    DECLARE @MaxOperacionesATM INT;
    DECLARE @MaxOperacionesHumano INT;
    DECLARE @ComisionATM DECIMAL(18,2);
    DECLARE @ComisionHumano DECIMAL(18,2);
    DECLARE @OperacionesATM INT;
    DECLARE @OperacionesHumano INT;
    DECLARE @MontoIntereses DECIMAL(18,2);
    DECLARE @MontoExcesoATM DECIMAL(18,2);
    DECLARE @MontoExcesoHumano DECIMAL(18,2);
    DECLARE @MontoMulta DECIMAL(18,2);
    DECLARE @TotalCargos DECIMAL(18,2);
    DECLARE @FechaInicioNueva DATE;
    DECLARE @FechaFinNueva DATE;
    DECLARE @MesSiguiente DATE;
    DECLARE @ReferenciaOrigen VARCHAR(128);
    DECLARE @Secuencia TINYINT;
    DECLARE @TipoMovimiento INT;
    DECLARE @MontoMovimiento DECIMAL(18,2);
    DECLARE @DescripcionMovimiento NVARCHAR(256);


    SET @outResultCode = 0;
    SET @outIdNuevoEstadoCuenta = NULL;

    IF @inNumeroCuenta IS NULL
        OR LTRIM(RTRIM(@inNumeroCuenta)) = ''
        OR @inFechaCierre IS NULL
    BEGIN
        SET @outResultCode = 50300;
        RETURN;
    END;

BEGIN TRY
    BEGIN TRANSACTION;

    --Bloqueo de cuenta para que el saldo no cambie a la hora de cierre
    SELECT
        @IdCuenta = C.Id,
        @FechaCreacion = C.FechaCreacion,
        @SaldoCuenta = C.Saldo,
        @TasaInteresAnual = T.TasaInteresAnual,
        @SaldoMinimoRequerido = T.SaldoMinimo,
        @MultaSaldoMin = T.MultaSaldoMin,
        @CargoMensual = T.CargoMensual,
        @MaxOperacionesATM = T.NumRetirosAutomatico,
        @MaxOperacionesHumano = T.NumRetirosHumano,
        @ComisionATM = T.ComisionAutomatico,
        @ComisionHumano = T.ComisionHumano
    FROM dbo.Cuenta AS C WITH (UPDLOCK, HOLDLOCK)
    INNER JOIN dbo.TipoCuentaAhorro as T 
        ON T.Id = C.IdTipoCuentaAhorro
    WHERE C.NumeroCuenta = @inNumeroCuenta;

    IF @idCuenta IS NULL
    BEGIN
        THROW 50301, 'La cuenta no existe', 1;
    END;

    --Cuando el cierre se realiza SOLO el ultiimo dia del periodo
    SELECT
        @IdEstadoCuenta = MIN(Id),
        @CantidadEstados = COUNT(*)
    FROM dbo.EstadoCuenta WITH (UPDLOCK, HOLDLOCK)
    WHERE IdCuenta = @IdCuenta
        AND FechaFin = @inFechaCierre
        AND FechaInicio <= @inFechaCierre;

    IF @CantidadEstados <> 1
    BEGIN 
        THROW 50302, 'No existe un único estado de cierre en la fecha', 1;
    END;

    SET @FechaInicioNueva = DATEADD(DAY, 1, @inFechaCierre);


    --Para no repedir un cierre que ya hizo el siguiente periodo
    IF EXISTS(
        SELECT 1
        FROM dbo.EstadoCuenta
        WHERE IdCuenta = @IdCuenta  AND FechaInicio = @FechaInicioNueva
    )
    BEGIN
        THROW 50303, 'El periodo ya fue cerrado', 1;
    END;

    SELECT
        @SaldoPeriodo = SaldoFinal,
        @SaldoMinimoPeriodo = SaldoMinimo,
        @OperacionesATM = CantOperacionesATM,
        @OperacionesHumano = CantOperacionesHumano
    FROM dbo.EstadoCuenta
    WHERE Id = @IdEstadoCuenta;


    IF @OperacionesATM IS NULL OR @OperacionesHumano IS NULL
    BEGIN
        THROW 50304, 'El estado tiene contadores sin inicializar.', 1;
    END;


    IF @SaldoCuenta <> @SaldoPeriodo
    BEGIN
        THROW 50305, 'El saldo de la cuenta no coincide con el estado actual.', 1;
    END;

    
    --Tipos de movimiento automatico
    IF (
        SELECT COUNT(*)
        FROM dbo.TipoMovimiento
        WHERE (Id = 12 AND Nombre = 'Intereses Mensuales' AND Accion = 'Credito')
            OR (Id = 7 AND Nombre = 'Comision Exceso ATM' AND Accion = 'Debito')
            OR (Id = 6 AND Nombre = 'Comision Exceso Ventana' AND Accion = 'Debito')
            OR (Id = 16 AND Nombre = 'Multa Saldo Minimo' AND Accion = 'Debito')
            OR (Id = 11 AND Nombre = 'Cargo Servicio Mensual' AND Accion = 'Debito')
    ) <> 5
    BEGIN
        THROW 50306, 'Faltan tipos de movimiento para el cierre.', 1;
    END;

    --La tasa del catalogo se divide entre 12
    SET @MontoIntereses = ROUND (
        @SaldoMinimoPeriodo * @TasaInteresAnual / 1200.0, 2
    );


    --NumRetiros es el limite de operaciones gratis por periodo
    SET @MontoExcesoATM = CASE
        WHEN @OperacionesATM > @MaxOperacionesATM
        THEN (@OperacionesATM - @MaxOperacionesATM) * @ComisionATM
        ELSE 0 END;

    SET @MontoExcesoHumano = CASE
        WHEN @OperacionesHumano > @MaxOperacionesHumano
        THEN (@OperacionesHumano - @MaxOperacionesHumano) * @ComisionHumano
        ELSE 0 END;

    SET @MontoMulta = CASE
        WHEN @SaldoMinimoPeriodo < @SaldoMinimoRequerido
        THEN @MultaSaldoMin
        ELSE 0 END;

    SET @TotalCargos = @MontoExcesoATM + @MontoExcesoHumano + @MontoMulta + @CargoMensual;


    --No saldos negativos, si no alcanza se revierte
    IF @SaldoCuenta + @MontoIntereses < @TotalCargos
    BEGIN
        THROW 50307, 'Saldo insuficiente para los cargos del cierre.', 1;
    END;


    --Referencia establa del cierre, diferente para cada cuenta y fecha
    SET @ReferenciaOrigen = 'CIERRE:' + @inNumeroCuenta + ':' + CONVERT(CHAR(8), @inFechaCierre, 112);

    IF EXISTS (
        SELECT 1
        FROM dbo.Movimiento
        WHERE ReferenciaOrigen = @ReferenciaOrigen
    )
    BEGIN
        THROW 50308, 'Ya existen movimientos para este cierre.', 1;
    END;

    SET @SaldoTrabajo = @SaldoCuenta;
    SET @SaldoMinimoFinal = @SaldoMinimoPeriodo;
    SET @Secuencia = 1;


    --Registro en oden los movimientos + del cierre
    WHILE @Secuencia <= 5
    BEGIN
        SELECT
            @TipoMovimiento = CASE @Secuencia
                WHEN 1 THEN 12
                WHEN 2 THEN 7
                WHEN 3 THEN 6
                WHEN 4 THEN 16
                WHEN 5 THEN 11 END,
            @MontoMovimiento = CASE @Secuencia
                WHEN 1 THEN @MontoIntereses
                WHEN 2 THEN @MontoExcesoATM
                WHEN 3 THEN @MontoExcesoHumano
                WHEN 4 THEN @MontoMulta
                WHEN 5 THEN @CargoMensual END,
            @DescripcionMovimiento = CASE @Secuencia
                WHEN 1 THEN N'Intereses mensuales'
                WHEN 2 THEN N'Comision por exceso de operaciones ATM'
                WHEN 3 THEN N'Comision por exceso de operaciones en ventanilla'
                WHEN 4 THEN N'Multa por saldo minimo'
                WHEN 5 THEN N'Cargo por servicio mensual' END;

        IF @MontoMovimiento > 0
        BEGIN
            IF @Secuencia = 1
                SET @SaldoTrabajo = @SaldoTrabajo + @MontoMovimiento;
            ELSE
                SET @SaldoTrabajo = @SaldoTrabajo - @MontoMovimiento;

            INSERT INTO dbo.Movimiento (
                IdEstadoCuenta,
                IdTipoMovimiento,
                FechaMovimiento,
                Monto,
                Descripcion,
                SaldoPosterior,
                ReferenciaOrigen,
                SecuenciaOrigen
            )
            VALUES (
                @IdEstadoCuenta,
                @TipoMovimiento,
                @inFechaCierre,
                @MontoMovimiento,
                @DescripcionMovimiento,
                @SaldoTrabajo,
                @ReferenciaOrigen,
                @Secuencia
            );

            IF @SaldoTrabajo < @SaldoMinimoFinal
                SET @SaldoMinimoFinal = @SaldoTrabajo;
            END;

            SET @Secuencia = @Secuencia + 1;
        END;

        UPDATE dbo.Cuenta
        SET Saldo = @SaldoTrabajo
        WHERE Id = @IdCuenta;

        UPDATE dbo.EstadoCuenta
        SET SaldoFinal = @SaldoTrabajo,
            SaldoMinimo = @SaldoMinimoFinal,
            InteresesAcumulados = @MontoIntereses
        WHERE Id = @IdEstadoCuenta;


        --Vencimiento se queda con el dia original de creacion, si es corto usa el ultimo dia
        SET @MesSiguiente = DATEADD(MONTH, 1, @inFechaCierre);

        IF DAY(@FechaCreacion) > DAY(EOMONTH(@MesSiguiente))
            SET @FechaFinNueva = EOMONTH(@MesSiguiente);
        ELSE
            SET @FechaFinNueva = DATEFROMPARTS(
                YEAR(@MesSiguiente), MONTH(@MesSiguiente), DAY(@FechaCreacion)
            );


        INSERT INTO dbo.EstadoCuenta (
            IdCuenta,
            FechaInicio,
            FechaFin,
            SaldoInicial,
            SaldoMinimo,
            SaldoFinal,
            InteresesAcumulados,
            CantRetiros,
            CantDepositos,
            CantSinpeEntrantes,
            CantSinpeSalientes,
            CantOperacionesATM,
            CantRetirosATM,
            CantOperacionesHumano,
            CantRetirosHumano
        )
        VALUES (
            @IdCuenta,
            @FechaInicioNueva,
            @FechaFinNueva,
            @SaldoTrabajo,
            @SaldoTrabajo,
            @SaldoTrabajo,
            0, 0, 0, 0, 0, 0, 0, 0, 0
        );

        SET @outIdNuevoEstadoCuenta = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
        SET @outResultCode = 0;

    END TRY

    BEGIN CATCH
        DECLARE @NumeroError INT = ERROR_NUMBER();
        DECLARE @SeveridadError INT = ERROR_SEVERITY();
        DECLARE @EstadoError INT = ERROR_STATE();
        DECLARE @ProcedimientoError NVARCHAR(128) = ERROR_PROCEDURE();
        DECLARE @LineaError INT = ERROR_LINE();
        DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();

        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @outIdNuevoEstadoCuenta = NULL;
        SET @outResultCode = @NumeroError;

        BEGIN TRY
            INSERT INTO dbo.ErrorBD
            (
                FechaHora,
                NumeroError,
                Severidad,
                Estado,
                Procedimiento,
                Linea,
                Mensaje
            )
            VALUES
            (
                SYSDATETIME(),
                @NumeroError,
                @SeveridadError,
                @EstadoError,
                @ProcedimientoError,
                @LineaError,
                @MensajeError
            );
        END TRY
        BEGIN CATCH
            PRINT CONCAT(
                'No se pudo registrar el error en ErrorBD: ',
                ERROR_MESSAGE()
            );
        END CATCH;

        PRINT @MensajeError;
    END CATCH;

END;
GO