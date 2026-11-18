/*

   El profesor pidio que pongamos nosotros una cuenta de administrador,
   porque en los XML del TP3 no viene ninguna. El administrador:
     - puede ver TODAS las cuentas (sp_ListarCuentasUsuario,
       sp_ConsultarEstadosCuenta y sp_ConsultarMovimientosEstadoCuenta ya
       lo permiten cuando EsAdministrador = 1), y
     - es el unico que puede abrir la pagina "Control de la simulacion".

   Datos: la persona es la misma que se uso en el TP2 (Franco Quiros Ramirez,
   cedula 130004000), porque dbo.Usuario exige una persona (IdPersona).
   Usuario: fquiros    Clave: admin1234 (se guarda en texto, igual que las
   demas claves: sp_IniciarSesion compara el texto tal cual).

   Se puede correr varias veces: si el usuario ya existe, no hace nada.
   Orden de instalacion: despues de CargarCatalogos (necesita el tipo de
   documento 1 = Cedula Nacional) y antes de Simulacion_TP3.sql.
   Limpiar_DatosTP3.sql vuelve a crear este usuario al final, para que una
   limpieza deje la base lista.

   Si algo falla: se deshace todo, se anota en dbo.ErrorBD y se vuelve a
   lanzar el error para que SSMS lo muestre.
*/
USE CuentaAhorrosTP2;
GO
SET NOCOUNT ON;

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

IF EXISTS (SELECT 1 FROM dbo.Usuario AS U
           WHERE U.NombreUsuario = @nombreUsuario)
BEGIN
    PRINT 'El usuario fquiros ya existe: no se hizo ningun cambio.';
END
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- La persona se reutiliza si ya existe (la cedula es unica).
        SELECT @idPersona = P.Id
        FROM dbo.Persona AS P
        WHERE P.ValorDocumentoIdentidad = @valorDoc;

        IF (@idPersona IS NULL)
        BEGIN
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
        END;

        INSERT INTO dbo.Usuario (
            NombreUsuario, Clave, EsAdministrador, IdPersona
        )
        VALUES (
            @nombreUsuario, @clave, 1, @idPersona
        );

        COMMIT TRANSACTION;
        PRINT 'Administrador fquiros creado.';
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
END;

-- Verificacion: debe salir 1 fila con EsAdministrador = 1
SELECT U.Id AS IdUsuario,
       U.NombreUsuario,
       U.EsAdministrador,
       P.Nombre,
       P.ValorDocumentoIdentidad,
       (SELECT COUNT(*) FROM dbo.Telefono AS T
        WHERE T.IdPersona = P.Id) AS Telefonos
FROM dbo.Usuario AS U
INNER JOIN dbo.Persona AS P
    ON P.Id = U.IdPersona
WHERE U.NombreUsuario = @nombreUsuario;
GO
