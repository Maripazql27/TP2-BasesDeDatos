/* ==========================================================================
   TP2 - Base de Datos 1 - Cuenta de Ahorros
   Script 06: consulta de estados de cuenta 
   ========================================================================== */
--USE CuentaAhorrosTP2; --conexion a base de datos real
USE PruebaTP2_Persona2 --conexion a base de datos de pruebla
GO

/* --------------------------------------------------------------------------
   sp_ConsultarEstadosCuenta
   Devuelve los ?ltimos 8 estados de cuenta de una cuenta, del m?s reciente
   al menos reciente, y registra la consulta en la bit?cora.
   El usuario debe poder ver la cuenta (UsuarioPuedeVer); el administrador
   puede ver cualquiera.

   Entrada : @inIdUsuario INT, @inNumeroCuenta VARCHAR(16)
   Salida  : @outResultCode
               0     = ?xito
               50002 = usuario o cuenta inexistente, o sin acceso a la cuenta
                       (no se distingue, para no revelar qu? cuentas existen)
   Consulta: IdEstadoCuenta, FechaInicio, FechaFin, FechaEmision,
             SaldoInicial, SaldoFinal, SaldoMinimo, InteresesAcumulados,
             CantRetiros, CantDepositos, CantSinpeEntrantes,
             CantSinpeSalientes
			---------- */
DROP PROCEDURE IF EXISTS dbo.sp_ConsultarEstadosCuenta;
GO
CREATE PROCEDURE dbo.sp_ConsultarEstadosCuenta
    @inIdUsuario INT                 -- usuario con sesi?n iniciada (lo pone el servidor)
    , @inNumeroCuenta VARCHAR(16)    -- n?mero de cuenta visible para el usuario, p. ej. '11000001'
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;          -- se asume ?xito hasta que se demuestre lo contrario

    DECLARE @idTipoOperacionConsulta INT = 7;   -- 'Consultar estado de cuenta' en el cat?logo
    DECLARE @idCuenta INT;                      -- Id interno de la cuenta (el usuario escribe el n?mero, la BD usa el Id)
    DECLARE @flagEsAdministrador BIT;           -- 1 si es administrador; queda NULL si el usuario no existe
    DECLARE @flagTieneAcceso BIT = 0;           -- empieza en 0 (sin acceso) y solo se sube a 1 si se comprueba

    BEGIN TRY
        -- Paso 1a: qui?n es el usuario? Si no existe, la variable queda NULL.
        SELECT @flagEsAdministrador = U.EsAdministrador
        FROM dbo.Usuario U
        WHERE U.Id = @inIdUsuario;

        -- Paso 1b: traducir el n?mero de cuenta al Id interno. Si no existe, queda NULL.
        SELECT @idCuenta = C.Id
        FROM dbo.Cuenta C
        WHERE C.NumeroCuenta = @inNumeroCuenta;

        -- Cualquiera de los dos NULL (usuario o cuenta inexistente) termina aqu?.
        IF (
               @flagEsAdministrador IS NULL
               OR @idCuenta IS NULL
           )
        BEGIN
            SET @outResultCode = 50002;
            RETURN;
        END;

        -- Paso 2: autorizaci?n.
        -- La autorizaci?n se valida AQU?, en la base de datos, no solo en la web:
        -- aunque alguien manipule la p?gina, no puede leer cuentas ajenas.
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
            SET @outResultCode = 50002;                   -- mismo c?digo que "no existe", a prop?sito
            RETURN;
        END;

        -- Paso 3: dejar constancia de la consulta (solo llega aqu? quien tiene acceso).
        -- sp_RegistrarBitacora recibe estos 5 par?metros @in y no
        -- tiene par?metro OUTPUT.
        EXEC dbo.sp_RegistrarBitacora
            @inIdUsuario = @inIdUsuario
            , @inIdTipoOperacion = @idTipoOperacionConsulta
            , @inIP = NULL
            , @inJsonAntes = NULL        -- consultar no modifica datos
            , @inJsonDespues = NULL;

        -- Paso 4: los datos. El orden es lo que hace que TOP (8) sean los M?S RECIENTES.
        -- TOP (8) + ORDER BY ... DESC = los 8 m?s recientes, del m?s nuevo al m?s viejo.
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