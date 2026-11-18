/*
     Toma el XML de operaciones completo y una fecha. Busca el nodo
     FechaOperacion de esa fecha e inserta, en este orden:
        Persona -> Telefono (x2) -> Cuenta -> Beneficiario
        -> Usuario -> UsuarioPuedeVer
     El trigger dbo.tr_Cuenta_AperturaEstadoCuenta abre solo el primer
     estado de cuenta cuando se inserta la Cuenta.
     NO procesa los nodos Movimientos (los aplica sp_AplicarMovimiento).
     Si la fecha no tiene nodo FechaOperacion no hace nada y devuelve 0
     (el simulador igual recorre todas las fechas).

   Todo el dia va en UNA transaccion: o entra todo o no entra nada.
   No llama a otros SP. Los errores se guardan en dbo.ErrorBD desde aqui.

   Codigos de salida (@outResultCode):
     0      OK
     50400  XML nulo
     50401  fecha nula
     50410  alguna Persona del dia no se inserto
     50411  algun Telefono no se inserto
     50412  alguna Cuenta no se inserto (persona dueña no existe)
     50413  algun Beneficiario no se inserto (cuenta o persona no existe)
     50414  algun Usuario no se inserto (persona no existe)
     50415  algun UsuarioPuedeVer no se inserto (usuario o cuenta no existe)
     50000  error de SQL (duplicado, CHECK, FK...). Detalle en dbo.ErrorBD

   Ejemplo de ejecucion:
     DECLARE @x XML = N'<Operaciones>...</Operaciones>';
     DECLARE @r INT;
     EXEC dbo.sp_CargarAltasDia
          @inXml = @x,
          @inFecha = '2026-03-01',
          @outResultCode = @r OUTPUT;
     SELECT @r;
*/

USE CuentaAhorrosTP2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CargarAltasDia
    @inXml          XML,
    @inFecha        DATE,
    @outResultCode  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Constantes
    DECLARE @true  BIT = 1;
    DECLARE @false BIT = 0;

    -- Variables
    DECLARE @fechaTexto VARCHAR(10);
    DECLARE @cantPersonas INT;
    DECLARE @cantCuentas INT;
    DECLARE @cantBeneficiarios INT;
    DECLARE @cantUsuarios INT;
    DECLARE @cantPuedeVer INT;

    SET @outResultCode = 0;

    -- Validaciones
    IF (@inXml IS NULL)
    BEGIN
        SET @outResultCode = 50400;
        RETURN;
    END;

    IF (@inFecha IS NULL)
    BEGIN
        SET @outResultCode = 50401;
        RETURN;
    END;

    -- Preprocesamiento: contar lo que trae este dia
    SET @fechaTexto = CONVERT(VARCHAR(10), @inFecha, 23);  -- yyyy-mm-dd

    SELECT @cantPersonas = COUNT(*)
    FROM @inXml.nodes(
        '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Persona'
    ) AS T(Nodo);

    SELECT @cantCuentas = COUNT(*)
    FROM @inXml.nodes(
        '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Cuenta'
    ) AS T(Nodo);

    SELECT @cantBeneficiarios = COUNT(*)
    FROM @inXml.nodes(
        '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Beneficiario'
    ) AS T(Nodo);

    SELECT @cantUsuarios = COUNT(*)
    FROM @inXml.nodes(
        '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Usuario'
    ) AS T(Nodo);

    SELECT @cantPuedeVer = COUNT(*)
    FROM @inXml.nodes(
        '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/UsuarioPuedeVer'
    ) AS T(Nodo);

    -- Dia sin altas: no hay nada que hacer
    IF (@cantPersonas + @cantCuentas + @cantBeneficiarios
        + @cantUsuarios + @cantPuedeVer = 0)
    BEGIN
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        --Personas
        INSERT INTO dbo.Persona (
            IdTipoDocuIdentidad,
            Nombre,
            ValorDocumentoIdentidad,
            FechaNacimiento,
            Email
        )
        SELECT
            T.Nodo.value('@TipoDocuIdentidad', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(64)'),
            T.Nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(32)'),
            T.Nodo.value('@FechaNacimiento', 'DATE'),
            T.Nodo.value('@Email', 'VARCHAR(128)')
        FROM @inXml.nodes(
            '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Persona'
        ) AS T(Nodo);

        IF (@@ROWCOUNT <> @cantPersonas)
            THROW 50410, 'No se insertaron todas las personas del dia.', 1;

        -- Telefonos (telefono1 y telefono2 de cada persona)
        INSERT INTO dbo.Telefono (IdPersona, Numero)
        SELECT
            P.Id,
            T.Nodo.value('@telefono1', 'VARCHAR(16)')
        FROM @inXml.nodes(
            '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Persona'
        ) AS T(Nodo)
        INNER JOIN dbo.Persona P
            ON P.ValorDocumentoIdentidad =
               T.Nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(32)');

        IF (@@ROWCOUNT <> @cantPersonas)
            THROW 50411, 'No se inserto el telefono1 de todas las personas.', 1;

        INSERT INTO dbo.Telefono (IdPersona, Numero)
        SELECT
            P.Id,
            T.Nodo.value('@telefono2', 'VARCHAR(16)')
        FROM @inXml.nodes(
            '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Persona'
        ) AS T(Nodo)
        INNER JOIN dbo.Persona P
            ON P.ValorDocumentoIdentidad =
               T.Nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(32)');

        IF (@@ROWCOUNT <> @cantPersonas)
            THROW 50411, 'No se inserto el telefono2 de todas las personas.', 1;

        --  Cuentas (el trigger abre el primer estado de cuenta)
        INSERT INTO dbo.Cuenta (
            IdPersona,
            IdTipoCuentaAhorro,
            NumeroCuenta,
            FechaCreacion,
            Saldo
        )
        SELECT
            P.Id,
            T.Nodo.value('@TipoCuentaId', 'INT'),
            T.Nodo.value('@NumeroCuenta', 'VARCHAR(16)'),
            T.Nodo.value('@FechaCreacion', 'DATE'),
            T.Nodo.value('@Saldo', 'DECIMAL(18,2)')
        FROM @inXml.nodes(
            '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Cuenta'
        ) AS T(Nodo)
        INNER JOIN dbo.Persona P
            ON P.ValorDocumentoIdentidad =
               T.Nodo.value('@ValorDocumentoIdentidadDelCliente',
                            'VARCHAR(32)');

        IF (@@ROWCOUNT <> @cantCuentas)
            THROW 50412, 'No se insertaron todas las cuentas del dia.', 1;

        --Beneficiarios
        INSERT INTO dbo.Beneficiario (
            IdCuenta,
            IdPersona,
            IdParentezco,
            Porcentaje
        )
        SELECT
            C.Id,
            P.Id,
            T.Nodo.value('@IdParentezco', 'INT'),
            T.Nodo.value('@Porcentaje', 'INT')
        FROM @inXml.nodes(
            '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Beneficiario'
        ) AS T(Nodo)
        INNER JOIN dbo.Cuenta C
            ON C.NumeroCuenta =
               T.Nodo.value('@NumeroCuenta', 'VARCHAR(16)')
        INNER JOIN dbo.Persona P
            ON P.ValorDocumentoIdentidad =
               T.Nodo.value('@ValorDocumentoIdentidadBeneficiario',
                            'VARCHAR(32)');

        IF (@@ROWCOUNT <> @cantBeneficiarios)
            THROW 50413, 'No se insertaron todos los beneficiarios del dia.', 1;

        -- Usuarios
        INSERT INTO dbo.Usuario (
            NombreUsuario,
            Clave,
            EsAdministrador,
            IdPersona
        )
        SELECT
            T.Nodo.value('@User', 'VARCHAR(64)'),
            T.Nodo.value('@Pass', 'VARCHAR(128)'),
            T.Nodo.value('@EsAdministrador', 'BIT'),
            P.Id
        FROM @inXml.nodes(
            '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Usuario'
        ) AS T(Nodo)
        INNER JOIN dbo.Persona P
            ON P.ValorDocumentoIdentidad =
               T.Nodo.value('@ValorDocId', 'VARCHAR(32)');

        IF (@@ROWCOUNT <> @cantUsuarios)
            THROW 50414, 'No se insertaron todos los usuarios del dia.', 1;

        --Permisos de visualizacion
        INSERT INTO dbo.UsuarioPuedeVer (IdUsuario, IdCuenta)
        SELECT
            U.Id,
            C.Id
        FROM @inXml.nodes(
            '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/UsuarioPuedeVer'
        ) AS T(Nodo)
        INNER JOIN dbo.Usuario U
            ON U.NombreUsuario =
               T.Nodo.value('@User', 'VARCHAR(64)')
        INNER JOIN dbo.Cuenta C
            ON C.NumeroCuenta =
               T.Nodo.value('@NumeroCuenta', 'VARCHAR(16)');

        IF (@@ROWCOUNT <> @cantPuedeVer)
            THROW 50415, 'No se insertaron todos los permisos del dia.', 1;

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

        SET @outResultCode = 50000;
    END CATCH;
END;
GO