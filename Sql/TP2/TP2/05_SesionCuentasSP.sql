/* ==========================================================================
   TP2 - Base de Datos 1 - Cuenta de Ahorros
   Script 05: procedimientos de sesi?n y cuentas

   Contiene:
     - sp_IniciarSesion          (clave en texto plano)
     - sp_ListarCuentasUsuario
     - sp_CerrarSesion
   ========================================================================== */


--USE CuentaAhorrosTP2; --conexion a base de datos real
USE PruebaTP2_Persona2 --conexion a base de datos de pruebla
GO

/* --------------------------------------------------------------------------
   sp_IniciarSesion
   Valida usuario y contrase?a. Si son correctos, registra el login en la
   bit?cora (tipo 1, con la IP) y devuelve el usuario. Solo se registran los
   logins EXITOSOS, como pide el enunciado.

   Entrada : @inNombreUsuario VARCHAR(64), @inClave VARCHAR(128), @inIP VARCHAR(45)
   Salida  : @outResultCode  0 = ?xito, 50001 = usuario o clave incorrectos
             (no se dice cu?l de los dos, para no ayudar a adivinar usuarios)
   Consulta (solo si ?xito): IdUsuario, EsAdministrador
   -------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS dbo.sp_IniciarSesion;   -- se borra si ya exist?a, para poder volver a ejecutar el script
GO
CREATE PROCEDURE dbo.sp_IniciarSesion
    @inNombreUsuario VARCHAR(64)     -- lo que el usuario escribi? en el campo "usuario"
    , @inClave VARCHAR(128)          -- lo que escribi? en el campo "contrase?a"
    , @inIP VARCHAR(45)              -- IP del equipo (45 caracteres alcanzan hasta para IPv6)
    , @outResultCode INT OUTPUT      -- aqu? se devuelve el resultado a quien llam? al SP
AS
BEGIN
    SET NOCOUNT ON;          -- evita los mensajes de "N filas afectadas" que estorban a la capa web
    SET @outResultCode = 0;  -- se asume ?xito; solo cambia si se detecta un error

    DECLARE @idTipoOperacionLogin INT = 1;   -- 'Login' en el cat?logo de tipos de operaci?n
    DECLARE @idUsuario INT;                  -- quedar? con el Id del usuario si las credenciales son v?lidas
    DECLARE @flagEsAdministrador BIT;        -- 1 si el usuario es administrador (l?gica positiva)

    BEGIN TRY
        -- Busca un usuario que coincida en nombre Y en clave a la vez.
        -- Si no hay coincidencia, el SELECT no asigna nada y @idUsuario se queda en NULL.
        -- COLLATE ..._CS_AS = Case Sensitive, Accent Sensitive: distingue may?sculas y tildes en la clave.
        SELECT @idUsuario = U.Id
            , @flagEsAdministrador = U.EsAdministrador
        FROM dbo.Usuario U
        WHERE U.NombreUsuario = @inNombreUsuario
          AND U.Clave = @inClave COLLATE Latin1_General_CS_AS;

        -- NULL significa que no se encontr? a nadie: credenciales incorrectas.
        -- Se corta aqu? con RETURN: no se registra bit?cora ni se devuelve nada.
        IF @idUsuario IS NULL
        BEGIN
            SET @outResultCode = 50001;
            RETURN;
        END;

        -- Llegar aqu? significa que el login es correcto: se anota en la bit?cora.
        -- Se supone que sp_RegistrarBitacora recibe estos 5 par?metros @in y no
        -- tiene par?metro OUTPUT. Si Persona 1 lo define distinto, ajustar aqu?.
        EXEC dbo.sp_RegistrarBitacora
            @inIdUsuario = @idUsuario
            , @inIdTipoOperacion = @idTipoOperacionLogin
            , @inIP = @inIP
            , @inJsonAntes = NULL        -- un login no cambia datos, as? que no hay "antes"
            , @inJsonDespues = NULL;     -- ni "despu?s"

        -- Esto es lo que la web recibe: con el IdUsuario guarda la sesi?n y con
        -- EsAdministrador decide qu? mostrar.
        SELECT @idUsuario AS IdUsuario
            , @flagEsAdministrador AS EsAdministrador;
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

/* --------------------------------------------------------------------------
   sp_ListarCuentasUsuario
   Devuelve las cuentas que el usuario puede ver. El administrador ve todas.

   Entrada : @inIdUsuario INT
   Salida  : @outResultCode  0 = ?xito, 50002 = usuario inexistente
   Consulta: IdCuenta, NumeroCuenta, Saldo, NombreTipoCuenta
   -------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS dbo.sp_ListarCuentasUsuario;
GO
CREATE PROCEDURE dbo.sp_ListarCuentasUsuario
    @inIdUsuario INT                 -- Id del usuario con sesi?n iniciada (lo pone el servidor, no el navegador)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;          -- evita mensajes de 'N filas afectadas' que estorban a la capa web
    SET @outResultCode = 0;  -- se asume ?xito; solo cambia si se detecta un error

    DECLARE @flagEsAdministrador BIT;   -- 1 si el usuario es administrador 

    BEGIN TRY
        -- Averigua si el usuario es administrador. Si el Id no existe, la variable queda NULL.
        SELECT @flagEsAdministrador = U.EsAdministrador
        FROM dbo.Usuario U
        WHERE U.Id = @inIdUsuario;

        -- Usuario inexistente: no tiene acceso a nada.
        -- se compara con IS NULL (no con = NULL).
        IF @flagEsAdministrador IS NULL
        BEGIN
            SET @outResultCode = 50002;
            RETURN;
        END;

        -- El administrador ve todas las cuentas; el cliente, solo las que aparecen
        -- en UsuarioPuedeVer (relaci?n muchos a muchos usuario-cuenta).
        IF @flagEsAdministrador = 1
        BEGIN
            -- Administrador: todas las cuentas. Cuenta -> tipo de cuenta para traer el nombre del tipo.
            SELECT C.Id AS IdCuenta
                , C.NumeroCuenta
                , C.Saldo
                , T.Nombre AS NombreTipoCuenta   -- se renombra para que la web reciba un nombre claro
            FROM dbo.Cuenta C
            INNER JOIN dbo.TipoCuentaAhorro T
                ON T.Id = C.IdTipoCuentaAhorro
            ORDER BY C.NumeroCuenta;
        END
        ELSE
        BEGIN
            -- Cliente: se parte de UsuarioPuedeVer (filtrada por su Id) y de ah? se llega a
            -- la cuenta y a su tipo. Sin fila en UsuarioPuedeVer, la cuenta no aparece.
            SELECT C.Id AS IdCuenta
                , C.NumeroCuenta
                , C.Saldo
                , T.Nombre AS NombreTipoCuenta
            FROM dbo.UsuarioPuedeVer V
            INNER JOIN dbo.Cuenta C
                ON C.Id = V.IdCuenta
            INNER JOIN dbo.TipoCuentaAhorro T
                ON T.Id = C.IdTipoCuentaAhorro
            WHERE V.IdUsuario = @inIdUsuario
            ORDER BY C.NumeroCuenta;
        END;
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

/* --------------------------------------------------------------------------
   sp_CerrarSesion
   Registra el logout en la bit?cora (usuario, operaci?n, fecha y hora).
   Es una sola escritura (dentro de sp_RegistrarBitacora): sin transacci?n.

   Entrada : @inIdUsuario INT
   Salida  : @outResultCode  0 = ?xito, 50002 = usuario inexistente
   -------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS dbo.sp_CerrarSesion;
GO
CREATE PROCEDURE dbo.sp_CerrarSesion
    @inIdUsuario INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    DECLARE @idTipoOperacionLogout INT = 2;   -- 'Logout' en el cat?logo de tipos de operaci?n

    BEGIN TRY
        -- Si el usuario no existe no se escribe nada en la bit?cora.
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario U WHERE U.Id = @inIdUsuario)
        BEGIN
            SET @outResultCode = 50002;
            RETURN;
        END;

        -- sp_RegistrarBitacora recibe estos 5 par?metros @in y no
        -- tiene par?metro OUTPUT.
        EXEC dbo.sp_RegistrarBitacora
            @inIdUsuario = @inIdUsuario
            , @inIdTipoOperacion = @idTipoOperacionLogout
            , @inIP = NULL               -- el logout no guarda IP
            , @inJsonAntes = NULL
            , @inJsonDespues = NULL;
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