/* ==========================================================================
   TP2 - Base de Datos 1 - Cuenta de Ahorros
   Script 06: consulta de estados de cuenta 
   ========================================================================== */
USE CuentaAhorrosTP2;   
GO

/* --------------------------------------------------------------------------
   sp_ConsultarEstadosCuenta
   Devuelve los ultimos 8 estados de cuenta de una cuenta, del mas reciente
   al menos reciente, y registra la consulta en la bitacora.
   El usuario debe poder ver la cuenta (UsuarioPuedeVer); el administrador
   puede ver cualquiera.

   Entrada : @inIdUsuario INT, @inNumeroCuenta VARCHAR(16)
   Salida  : @outResultCode
               0     = exito
               50002 = usuario o cuenta inexistente, o sin acceso a la cuenta
                       (no se distingue, para no revelar que cuentas existen)
   Consulta: IdEstadoCuenta, FechaInicio, FechaFin, FechaEmision,
             SaldoInicial, SaldoFinal, SaldoMinimo, InteresesAcumulados,
             CantRetiros, CantDepositos, CantSinpeEntrantes,
             CantSinpeSalientes
			---------- */
DROP PROCEDURE IF EXISTS dbo.sp_ConsultarEstadosCuenta;
GO
CREATE PROCEDURE dbo.sp_ConsultarEstadosCuenta
    @inIdUsuario INT                 -- usuario con sesion iniciada (lo pone el servidor)
    , @inNumeroCuenta VARCHAR(16)    -- numero de cuenta visible para el usuario, p. ej. '11000001'
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;          -- se asume exito hasta que se demuestre lo contrario

    DECLARE @idTipoOperacionConsulta INT = 7;   -- 'Consultar estado de cuenta' en el catalogo
    DECLARE @idCuenta INT;                      -- Id interno de la cuenta (el usuario escribe el numero, la BD usa el Id)
    DECLARE @flagEsAdministrador BIT;           -- 1 si es administrador; queda NULL si el usuario no existe
    DECLARE @flagTieneAcceso BIT = 0;           -- empieza en 0 (sin acceso) y solo se sube a 1 si se comprueba

    BEGIN TRY
        -- Paso 1a: quien es el usuario? Si no existe, la variable queda NULL.
        SELECT @flagEsAdministrador = U.EsAdministrador
        FROM dbo.Usuario U
        WHERE U.Id = @inIdUsuario;

        -- Paso 1b: traducir el numero de cuenta al Id interno. Si no existe, queda NULL.
        SELECT @idCuenta = C.Id
        FROM dbo.Cuenta C
        WHERE C.NumeroCuenta = @inNumeroCuenta;

        -- Cualquiera de los dos NULL (usuario o cuenta inexistente) termina aqui.
        IF (
               @flagEsAdministrador IS NULL
               OR @idCuenta IS NULL
           )
        BEGIN
            SET @outResultCode = 50002;
            RETURN;
        END;

        -- Paso 2: autorizacion.
        -- La autorizacion se valida AQUi, en la base de datos, no solo en la web:
        -- aunque alguien manipule la pagina, no puede leer cuentas ajenas.
        IF (@flagEsAdministrador = 1)
        BEGIN
            SET @flagTieneAcceso = 1;                     -- el administrador ve cualquier cuenta
        END
        ELSE
        BEGIN
            -- el cliente solo si esa cuenta está asociada a él
            IF EXISTS (SELECT 1
                       FROM dbo.UsuarioPuedeVer V
                       WHERE V.IdUsuario = @inIdUsuario
                         AND V.IdCuenta = @idCuenta)
            BEGIN
                SET @flagTieneAcceso = 1;
            END;
        END;

        IF @flagTieneAcceso = 0
        BEGIN
            SET @outResultCode = 50002;                   -- mismo codigo que "no existe", a proposito
            RETURN;
        END;

        -- Paso 3: dejar constancia de la consulta (solo llega aqui quien tiene acceso).
        -- sp_RegistrarBitacora (Persona 1) devuelve @outResultCode (OUTPUT).
        DECLARE @codigoBitacora INT;
        EXEC dbo.sp_RegistrarBitacora
            @inIdUsuario = @inIdUsuario
            , @inIdTipoOperacion = @idTipoOperacionConsulta
            , @inIP = NULL
            , @inJsonAntes = NULL        -- consultar no modifica datos
            , @inJsonDespues = NULL
            , @outResultCode = @codigoBitacora OUTPUT;
        IF (@codigoBitacora <> 0)
        BEGIN
            SET @outResultCode = @codigoBitacora;   -- la bitacora fallo: se devuelve su codigo
            RETURN;
        END;

        -- Paso 4: los datos. El orden es lo que hace que TOP (8) sean los MAS RECIENTES.
        -- TOP (8) + ORDER BY ... DESC = los 8 mas recientes, del mas nuevo al mas viejo.
        -- E.Id DESC desempata si dos estados tuvieran la misma FechaFin.
        SELECT TOP (8)
            E.Id AS IdEstadoCuenta
            , E.FechaInicio
            , E.FechaFin
            , DATEADD(DAY, 1, E.FechaFin) AS FechaEmision   -- calculada, no existe como columna
            , E.SaldoInicial
            , E.SaldoFinal
            , E.SaldoMinimo
            , E.InteresesAcumulados
            , E.CantRetiros
            , E.CantDepositos
            , E.CantSinpeEntrantes
            , E.CantSinpeSalientes
        FROM dbo.EstadoCuenta E
        WHERE E.IdCuenta = @idCuenta
        ORDER BY E.FechaFin DESC, E.Id DESC;
    END TRY
    BEGIN CATCH
        -- Error inesperado (por ejemplo, falla al escribir en la bitácora):
        -- se guarda en ErrorBD con el procedimiento común y la web recibe 50000
        -- en vez de un error crudo.
        EXEC dbo.sp_RegistrarError;

        SET @outResultCode = 50000;
    END CATCH;
END
GO




-- SELECT TOP 10 * FROM dbo.Bitacora ORDER BY 1 DESC; --prueba y check de la bitacora

USE CuentaAhorrosTP2;   
GO
-- SELECT TOP 25 * FROM dbo.Bitacora ORDER BY Id DESC