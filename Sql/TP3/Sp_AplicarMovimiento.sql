--SP para identificar cuenta y tipomovimiento
--Comprobar que exista, rechaza operaciones duplicadas
--y debitos con fondos insuficientes, actualiza saldos
--genera sinpe como segundo movimiento y confirma cambios, sino nada

USE CuentaAhorrosTP2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AplicarMovimiento
    @inNumeroCuenta VARCHAR(16),
    @inTipoMovimiento VARCHAR(64),
    @inFechaMovimiento DATE,
    @inMonto DECIMAL(18,2),
    @inDescripcion NVARCHAR(256),
    @inReferenciaOrigen VARCHAR(128),
    @outResultCode INT OUTPUT,
    @outIdMovimiento INT OUTPUT
AS
BEGIN

	SET NOCOUNT ON;
	DECLARE @IdTipoMovimiento INT;
    DECLARE @Accion VARCHAR(7);
    DECLARE @IdCuenta INT;
    DECLARE @IdEstadoCuenta INT;
    DECLARE @CantidadEstados INT;
    DECLARE @SaldoActual DECIMAL(18,2);
    DECLARE @SaldoPrincipal DECIMAL(18,2);
    DECLARE @SaldoFinal DECIMAL(18,2);
    DECLARE @LimiteSinpe DECIMAL(18,2);
    DECLARE @ComisionSinpe DECIMAL(18,2);
    DECLARE @MontoComision DECIMAL(18,2) = 0;
    DECLARE @TotalSinpeAnterior DECIMAL(18,2) = 0;
    DECLARE @IdTipoComision INT;
    SET @outResultCode = 0;
    SET @outIdMovimiento = NULL;

    -- Validar parametros.
    IF @inNumeroCuenta IS NULL
       OR LTRIM(RTRIM(@inNumeroCuenta)) = ''
       OR @inTipoMovimiento IS NULL
       OR LTRIM(RTRIM(@inTipoMovimiento)) = ''
       OR @inFechaMovimiento IS NULL
       OR @inMonto IS NULL
       OR @inMonto <= 0
       OR @inDescripcion IS NULL
       OR LTRIM(RTRIM(@inDescripcion)) = ''
       OR @inReferenciaOrigen IS NULL
       OR LTRIM(RTRIM(@inReferenciaOrigen)) = ''
    BEGIN
        SET @outResultCode = 50200;
        RETURN;
    END;

    -- Solo movimientos operativos del XML
    SELECT
        @IdTipoMovimiento = Id,
        @Accion = Accion
    FROM dbo.TipoMovimiento
    WHERE Nombre = @inTipoMovimiento
      AND Id IN (1, 2, 3, 4, 5, 8, 9);

    IF @IdTipoMovimiento IS NULL
    BEGIN
        SET @outResultCode = 50201;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- Bloquea la cuenta en la operacion
        SELECT
            @IdCuenta = C.Id,
            @SaldoActual = C.Saldo,
            @LimiteSinpe = T.MontoMaxSinpeDiario,
            @ComisionSinpe = T.ComisionSinpe
        FROM dbo.Cuenta AS C WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.TipoCuentaAhorro AS T
            ON T.Id = C.IdTipoCuentaAhorro
        WHERE C.NumeroCuenta = @inNumeroCuenta;

        IF @IdCuenta IS NULL
        BEGIN
            THROW 50202, 'La cuenta no existe.', 1;
        END;

        -- para no volver a aplicar una operacion confirmada
        IF EXISTS (
            SELECT 1
            FROM dbo.Movimiento
            WHERE ReferenciaOrigen = @inReferenciaOrigen
              AND SecuenciaOrigen IN (1, 2)
        )
        BEGIN
            THROW 50203, 'El movimiento ya fue registrado.', 1;
        END;

        -- Localiza el unico estado correspondiente a la fecha
        SELECT
            @IdEstadoCuenta = MIN(Id),
            @CantidadEstados = COUNT(*)
        FROM dbo.EstadoCuenta WITH (UPDLOCK, HOLDLOCK)
        WHERE IdCuenta = @IdCuenta
          AND @inFechaMovimiento BETWEEN FechaInicio AND FechaFin;

        IF @CantidadEstados <> 1
        BEGIN
            THROW 50204,
                'No existe un unico estado de cuenta para la fecha.',
                1;
        END;

        -- Los estados nuevos deben tener contadores inicializados
        IF EXISTS (
            SELECT 1
            FROM dbo.EstadoCuenta
            WHERE Id = @IdEstadoCuenta
              AND (
                  CantOperacionesATM IS NULL
                  OR CantRetirosATM IS NULL
                  OR CantOperacionesHumano IS NULL
                  OR CantRetirosHumano IS NULL
              )
        )
        BEGIN
            THROW 50205,
                'El estado de cuenta tiene contadores sin inicializar.',
                1;
        END;


         -- Calcula el saldo posterior al movimiento principal
        IF @Accion = 'Credito'
        BEGIN
            SET @SaldoPrincipal = @SaldoActual + @inMonto;
        END
        ELSE
        BEGIN
            SET @SaldoPrincipal = @SaldoActual - @inMonto;
        END;

        IF @SaldoPrincipal < 0
        BEGIN
            THROW 50206, 'Saldo insuficiente.', 1;
        END;


        -- En retiros SINPE se revisa lo enviado en el dia
        IF @IdTipoMovimiento = 9
        BEGIN
            IF @LimiteSinpe IS NULL OR @ComisionSinpe IS NULL
            BEGIN
                THROW 50207,
                    'Falta la configuracion SINPE del tipo de cuenta.',
                    1;
            END;



            SELECT
                @TotalSinpeAnterior = ISNULL(SUM(M.Monto), 0)
            FROM dbo.Movimiento AS M
            INNER JOIN dbo.EstadoCuenta AS E
                ON E.Id = M.IdEstadoCuenta
            WHERE E.IdCuenta = @IdCuenta
              AND M.FechaMovimiento = @inFechaMovimiento
              AND M.IdTipoMovimiento = 9;

            IF @TotalSinpeAnterior + @inMonto > @LimiteSinpe
            BEGIN
                SET @MontoComision = @ComisionSinpe;
            END;
        END;



        SET @SaldoFinal = @SaldoPrincipal - @MontoComision;
        IF @SaldoFinal < 0
        BEGIN
            THROW 50208,
                'Saldo insuficiente para el movimiento y su comision.', 1;
        END;



        IF @MontoComision > 0
        BEGIN
            SELECT @IdTipoComision = Id
            FROM dbo.TipoMovimiento
            WHERE Id = 10
              AND Nombre = 'Comision Sinpe'
              AND Accion = 'Debito';

            IF @IdTipoComision IS NULL
            BEGIN
                THROW 50209, 'No existe el tipo Comision Sinpe.', 1;
            END;
        END;



        -- Registra el movimiento principal
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
            @IdTipoMovimiento,
            @inFechaMovimiento,
            @inMonto,
            @inDescripcion,
            @SaldoPrincipal,
            @inReferenciaOrigen,
            1
        );

        SET @outIdMovimiento = SCOPE_IDENTITY();



        -- Registra la comision como segundo movimiento
        IF @MontoComision > 0
        BEGIN
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
                @IdTipoComision,
                @inFechaMovimiento,
                @MontoComision,
                N'Comision por exceder el limite diario SINPE',
                @SaldoFinal,
                @inReferenciaOrigen,
                2
            );
        END;


        -- Actualiza el saldo de la cuenta
        UPDATE dbo.Cuenta
        SET Saldo = @SaldoFinal
        WHERE Id = @IdCuenta;



        -- Actualiza saldo y contadores del estado vigente
        UPDATE dbo.EstadoCuenta
        SET
            SaldoFinal = @SaldoFinal,
            SaldoMinimo =
                CASE
                    WHEN @SaldoFinal < SaldoMinimo
                        THEN @SaldoFinal
                    ELSE SaldoMinimo
                END,
            CantDepositos = CantDepositos +
                CASE
                    WHEN @IdTipoMovimiento IN (1, 2, 8)
                        THEN 1 ELSE 0
                END,
            CantRetiros = CantRetiros +
                CASE
                    WHEN @IdTipoMovimiento IN (3, 4, 5, 9)
                        THEN 1 ELSE 0
                END,
            CantSinpeEntrantes = CantSinpeEntrantes +
                CASE
                    WHEN @IdTipoMovimiento = 8
                        THEN 1 ELSE 0
                END,
            CantSinpeSalientes = CantSinpeSalientes +
                CASE
                    WHEN @IdTipoMovimiento = 9
                        THEN 1 ELSE 0
                END,
            CantOperacionesATM = CantOperacionesATM +
                CASE
                    WHEN @IdTipoMovimiento IN (2, 4)
                        THEN 1 ELSE 0
                END,
            CantRetirosATM = CantRetirosATM +
                CASE
                    WHEN @IdTipoMovimiento = 4
                        THEN 1 ELSE 0
                END,
            CantOperacionesHumano = CantOperacionesHumano +
                CASE
                    WHEN @IdTipoMovimiento IN (1, 5)
                        THEN 1 ELSE 0
                END,
            CantRetirosHumano = CantRetirosHumano +
                CASE
                    WHEN @IdTipoMovimiento = 5
                        THEN 1 ELSE 0
                END
        WHERE Id = @IdEstadoCuenta;

        COMMIT TRANSACTION;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @outIdMovimiento = NULL;
        SET @outResultCode = ERROR_NUMBER();

        PRINT ERROR_MESSAGE();
    END CATCH;
END;
GO