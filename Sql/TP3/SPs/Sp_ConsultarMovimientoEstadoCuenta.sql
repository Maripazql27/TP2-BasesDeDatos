USE CuentaAhorrosTP2;
GO

/*
   Devuelve los movimientos de un estado de cuenta, en orden cronologico
   (del mas antiguo al mas reciente), con el monto con signo, el saldo
   posterior y la moneda de la cuenta. Registra la consulta en la bitacora
   (tipo de operacion 8).
   Permisos: un cliente solo puede ver las cuentas que aparecen en
   UsuarioPuedeVer; el administrador puede ver cualquiera.

   Entrada : @inIdUsuario        usuario que consulta
             @inNumeroCuenta     numero de la cuenta
             @inIdEstadoCuenta   estado de cuenta; debe pertenecer a la cuenta
   Salida  : @outResultCode
               0      = exito
               50002  = parametros invalidos, usuario o cuenta inexistente,
                        usuario sin acceso a la cuenta o estado de cuenta
                        que no es de esa cuenta
               50000  = error inesperado (queda en dbo.ErrorBD)
               otro   = codigo de error de sp_RegistrarBitacora

   Ejemplo de ejecucion:
     DECLARE @r INT;
     EXEC dbo.sp_ConsultarMovimientosEstadoCuenta
         @inIdUsuario = 1,
         @inNumeroCuenta = '11000001',
         @inIdEstadoCuenta = 1,
         @outResultCode = @r OUTPUT;
     SELECT @r AS CodigoResultado;
*/

CREATE OR ALTER PROCEDURE dbo.sp_ConsultarMovimientosEstadoCuenta
    @inIdUsuario INT
    , @inNumeroCuenta VARCHAR(16)
    , @inIdEstadoCuenta INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @idCuenta INT;
    DECLARE @flagEsAdministrador BIT;
    DECLARE @codigoBitacora INT;
    DECLARE @NombreMoneda VARCHAR(32);
    DECLARE @SimboloMoneda NVARCHAR(4);

    SET @outResultCode = 0;

    -- Validacion de parametros.
    IF @inIdUsuario IS NULL
        OR @inNumeroCuenta IS NULL
        OR LTRIM(RTRIM(@inNumeroCuenta)) = ''
        OR @inIdEstadoCuenta IS NULL
        OR @inIdEstadoCuenta <= 0
    BEGIN
        SET @outResultCode = 50002;
        RETURN;
    END;

    BEGIN TRY

        -- Identifica al usuario.
        SELECT
            @flagEsAdministrador = U.EsAdministrador
        FROM dbo.Usuario AS U
        WHERE U.Id = @inIdUsuario;

        -- Identifica la cuenta y su moneda.
        SELECT
            @idCuenta = C.Id
            , @NombreMoneda = TM.Nombre
            , @SimboloMoneda = TM.Simbolo
        FROM dbo.Cuenta AS C
        INNER JOIN dbo.TipoCuentaAhorro AS TC
            ON TC.Id = C.IdTipoCuentaAhorro
        INNER JOIN dbo.TipoMoneda AS TM
            ON TM.Id = TC.IdTipoMoneda
        WHERE C.NumeroCuenta = @inNumeroCuenta;

        IF @flagEsAdministrador IS NULL
            OR @idCuenta IS NULL
        BEGIN
            SET @outResultCode = 50002;
            RETURN;
        END;

        -- El administrador ve cualquier cuenta; el cliente, solo las autorizadas.
        IF @flagEsAdministrador = 0
            AND NOT EXISTS (
                SELECT 1
                FROM dbo.UsuarioPuedeVer AS UPV
                WHERE UPV.IdUsuario = @inIdUsuario
                    AND UPV.IdCuenta = @idCuenta
            )
        BEGIN
            SET @outResultCode = 50002;
            RETURN;
        END;

        -- El estado de cuenta debe pertenecer a la cuenta.
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.EstadoCuenta AS EC
            WHERE EC.Id = @inIdEstadoCuenta
                AND EC.IdCuenta = @idCuenta
        )
        BEGIN
            SET @outResultCode = 50002;
            RETURN;
        END;

        -- Se registra la consulta del detalle en la bitacora (tipo 8).
        EXEC dbo.sp_RegistrarBitacora
            @inIdUsuario = @inIdUsuario
            , @inIdTipoOperacion = 8
            , @inIP = NULL
            , @inJsonAntes = NULL
            , @inJsonDespues = NULL
            , @outResultCode = @codigoBitacora OUTPUT;

        IF @codigoBitacora IS NULL
            OR @codigoBitacora <> 0
        BEGIN
            SET @outResultCode = ISNULL(@codigoBitacora, 50000);
            RETURN;
        END;

        -- Detalle cronologico: fecha y, a igual fecha, el orden de registro.
        SELECT
            M.Id AS IdMovimiento
            , M.FechaMovimiento
            , M.Monto
            , TM.Accion
            , CASE
                WHEN TM.Accion = 'Debito' THEN -M.Monto
                ELSE M.Monto
              END AS MontoConSigno
            , M.Descripcion
            , M.SaldoPosterior
            , TM.Nombre AS TipoMovimiento
            , @NombreMoneda AS NombreMoneda
            , @SimboloMoneda AS SimboloMoneda
        FROM dbo.Movimiento AS M
        INNER JOIN dbo.TipoMovimiento AS TM
            ON TM.Id = M.IdTipoMovimiento
        WHERE M.IdEstadoCuenta = @inIdEstadoCuenta
        ORDER BY M.FechaMovimiento ASC, M.Id ASC;

        SET @outResultCode = 0;

    END TRY
    BEGIN CATCH

        EXEC dbo.sp_RegistrarError;

        SET @outResultCode = 50000;

    END CATCH;
END;
GO