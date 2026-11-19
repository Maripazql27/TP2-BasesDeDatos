
USE CuentaAhorrosTP2;
GO

--consulta todos los estados de cuenta de una cuenta (permisos quedaron igual y bitacora)


CREATE OR ALTER PROCEDURE dbo.sp_ConsultarEstadosCuenta
    @inIdUsuario INT,
    @inNumeroCuenta VARCHAR(16),
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idCuenta INT;
    DECLARE @flagEsAdministrador BIT;
    DECLARE @codigoBitacora INT;

    SET @outResultCode = 0;

    -- Valida parametros
    IF @inIdUsuario IS NULL
       OR @inNumeroCuenta IS NULL
       OR LTRIM(RTRIM(@inNumeroCuenta)) = ''
    BEGIN
        SET @outResultCode = 50002;
        RETURN;
    END;

    BEGIN TRY

        -- Identifica usuario
        SELECT
            @flagEsAdministrador = EsAdministrador
        FROM dbo.Usuario
        WHERE Id = @inIdUsuario;

        -- Identifica cuenta
        SELECT
            @idCuenta = Id
        FROM dbo.Cuenta
        WHERE NumeroCuenta = @inNumeroCuenta;

        IF @flagEsAdministrador IS NULL
           OR @idCuenta IS NULL
        BEGIN
            SET @outResultCode = 50002;
            RETURN;
        END;

        -- Admin cualquier cuenta y cliente solo cuentas autorizadas
        IF @flagEsAdministrador = 0
           AND NOT EXISTS (
               SELECT 1
               FROM dbo.UsuarioPuedeVer
               WHERE IdUsuario = @inIdUsuario
                 AND IdCuenta = @idCuenta
           )
        BEGIN
            SET @outResultCode = 50002;
            RETURN;
        END;

        -- Registrar la consulta en bitacora (7), no hace otra transaccion

        EXEC dbo.sp_RegistrarBitacora
            @inIdUsuario = @inIdUsuario,
            @inIdTipoOperacion = 7,
            @inIP = NULL,
            @inJsonAntes = NULL,
            @inJsonDespues = NULL,
            @outResultCode = @codigoBitacora OUTPUT;

        IF @codigoBitacora IS NULL
           OR @codigoBitacora <> 0
        BEGIN
            SET @outResultCode = ISNULL(@codigoBitacora, 50000);
            RETURN;
        END;

        -- periodos del mas reciente al mas antiguo (columnas igual)

        SELECT
            E.Id AS IdEstadoCuenta,
            E.FechaInicio,
            E.FechaFin,
            DATEADD(DAY, 1, E.FechaFin) AS FechaEmision,
            E.SaldoInicial,
            E.SaldoFinal,
            E.SaldoMinimo,
            E.InteresesAcumulados,
            E.CantRetiros,
            E.CantDepositos,
            E.CantSinpeEntrantes,
            E.CantSinpeSalientes,

            -- contadores neuvos
            E.CantOperacionesATM,
            E.CantRetirosATM,
            E.CantOperacionesHumano,
            E.CantRetirosHumano,

                       -- Total de operaciones SINPE 
            E.CantSinpeEntrantes + E.CantSinpeSalientes
                AS CantOperacionesSinpe,

            -- moneda de la cuenta
            TM.Simbolo AS SimboloMoneda,
            TM.Nombre  AS NombreMoneda

        FROM dbo.EstadoCuenta AS E
        --para la moneda de la cuenta
        INNER JOIN dbo.Cuenta AS C ON C.Id = E.IdCuenta
        INNER JOIN dbo.TipoCuentaAhorro AS TC ON TC.Id = C.IdTipoCuentaAhorro
        INNER JOIN dbo.TipoMoneda AS TM ON TM.Id = TC.IdTipoMoneda
        WHERE E.IdCuenta = @idCuenta
        ORDER BY E.FechaFin DESC, E.Id DESC;

        SET @outResultCode = 0;

    END TRY
    BEGIN CATCH

        EXEC dbo.sp_RegistrarError;

        SET @outResultCode = 50000;

    END CATCH;
END;
GO
