/*
   Limpieza de datos de la simulacion.
   Borra TODOS los datos de cuentas y movimientos, y el control de la
   simulacion (corridas y fechas), para poder volver a correr
   Simulacion_TP3.sql desde la primera fecha. Tambien borra los
   comprobantes (dbo.Comprobante). NO toca los catalogos
   (TipoMoneda, TipoCuentaAhorro, TipoMovimiento, etc.), ni los SP, ni el
   trigger. Tambien deja vacia dbo.ErrorBD y reinicia los Id para que
   empiecen en 1.
   El orden de los DELETE respeta las llaves foraneas (primero las hijas).

   Al final vuelve a crear el usuario administrador fquiros (el mismo bloque
   de Crear_Admin.sql), porque la limpieza borra todos los usuarios y
   personas. Asi, despues de limpiar, la base queda lista para la simulacion.
*/
USE CuentaAhorrosTP2;
GO

-- Control de la simulacion. Solo se reinicia el Id si la tabla tenia filas
-- (en una tabla recien creada, RESEED 0 haria que el primer Id fuera 0).
IF OBJECT_ID('dbo.ControlSimulacion', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.ControlSimulacion)
    BEGIN
        DELETE FROM dbo.ControlSimulacion;
        DBCC CHECKIDENT ('dbo.ControlSimulacion', RESEED, 0);
    END;
END;

IF OBJECT_ID('dbo.CorridaSimulacion', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.CorridaSimulacion)
    BEGIN
        DELETE FROM dbo.CorridaSimulacion;
        DBCC CHECKIDENT ('dbo.CorridaSimulacion', RESEED, 0);
    END;
END;

DELETE FROM dbo.Bitacora;
DELETE FROM dbo.UsuarioPuedeVer;
DELETE FROM dbo.Usuario;
DELETE FROM dbo.Movimiento;

-- Comprobantes: despues de Movimiento (que tiene el FK al comprobante) y
-- antes de Cuenta. Solo se reinicia el Id si la tabla tenia filas.
IF OBJECT_ID('dbo.Comprobante', 'U') IS NOT NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Comprobante)
    BEGIN
        DELETE FROM dbo.Comprobante;
        DBCC CHECKIDENT ('dbo.Comprobante', RESEED, 0);
    END;
END;

DELETE FROM dbo.EstadoCuenta;
DELETE FROM dbo.Beneficiario;
DELETE FROM dbo.Cuenta;
DELETE FROM dbo.Telefono;
DELETE FROM dbo.Persona;
DELETE FROM dbo.ErrorBD;

DBCC CHECKIDENT ('dbo.Bitacora',        RESEED, 0);
DBCC CHECKIDENT ('dbo.UsuarioPuedeVer', RESEED, 0);
DBCC CHECKIDENT ('dbo.Usuario',         RESEED, 0);
DBCC CHECKIDENT ('dbo.Movimiento',      RESEED, 0);
DBCC CHECKIDENT ('dbo.EstadoCuenta',    RESEED, 0);
DBCC CHECKIDENT ('dbo.Beneficiario',    RESEED, 0);
DBCC CHECKIDENT ('dbo.Cuenta',          RESEED, 0);
DBCC CHECKIDENT ('dbo.Telefono',        RESEED, 0);
DBCC CHECKIDENT ('dbo.Persona',         RESEED, 0);
DBCC CHECKIDENT ('dbo.ErrorBD',         RESEED, 0);
GO

-- Administrador (fquiros / admin1234). Se vuelve a crear porque arriba se
-- borraron todos los usuarios y personas. Es el mismo bloque de
-- Crear_Admin.sql: los Id reiniciados hacen que quede con Id 1.
DECLARE @nombreUsuario VARCHAR(64)  = 'fquiros';
DECLARE @clave         VARCHAR(128) = 'admin1234';
DECLARE @idTipoDocu    INT          = 1;                       -- Cedula Nacional
DECLARE @valorDoc      VARCHAR(32)  = '130004000';
DECLARE @nombre        VARCHAR(64)  = 'Franco Quiros Ramirez';
DECLARE @fechaNac      DATE         = '1972-05-14';
DECLARE @email         VARCHAR(128) = 'fquiros@example.com';
DECLARE @telefono1     VARCHAR(16)  = '65360060';
DECLARE @telefono2     VARCHAR(16)  = '23746093';
DECLARE @idPersona     INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Persona (
        IdTipoDocuIdentidad, Nombre, ValorDocumentoIdentidad,
        FechaNacimiento, Email
    )
    VALUES (
        @idTipoDocu, @nombre, @valorDoc, @fechaNac, @email
    );

    SET @idPersona = SCOPE_IDENTITY();

    INSERT INTO dbo.Telefono (IdPersona, Numero)
    VALUES (@idPersona, @telefono1),
           (@idPersona, @telefono2);

    INSERT INTO dbo.Usuario (
        NombreUsuario, Clave, EsAdministrador, IdPersona
    )
    VALUES (
        @nombreUsuario, @clave, 1, @idPersona
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;

    INSERT INTO dbo.ErrorBD (
        NumeroError, Severidad, Estado, Procedimiento, Linea, Mensaje
    )
    VALUES (
        ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(),
        ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE()
    );

    THROW;
END CATCH;
GO

-- Verificacion: solo queda el administrador (1 persona, 1 usuario, 2 telefonos),
-- lo demas en 0, y los catalogos intactos (TipoMovimiento = 18)
SELECT (SELECT COUNT(*) FROM dbo.Persona)           AS Personas_esperado_1,
       (SELECT COUNT(*) FROM dbo.Usuario)           AS Usuarios_esperado_1,
       (SELECT COUNT(*) FROM dbo.Cuenta)            AS Cuentas,
       (SELECT COUNT(*) FROM dbo.EstadoCuenta)      AS Estados,
       (SELECT COUNT(*) FROM dbo.Movimiento)        AS Movimientos,
       (SELECT COUNT(*) FROM dbo.Comprobante)       AS Comprobantes,
       (SELECT COUNT(*) FROM dbo.ErrorBD)           AS Errores,
       (SELECT COUNT(*) FROM dbo.ControlSimulacion) AS FechasControl,
       (SELECT COUNT(*) FROM dbo.CorridaSimulacion) AS Corridas,
       (SELECT COUNT(*) FROM dbo.TipoMovimiento)    AS TiposMov_esperado_18;
GO
