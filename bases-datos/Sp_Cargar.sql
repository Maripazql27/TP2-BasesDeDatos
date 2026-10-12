
USE CuentaAhorrosTP2;
GO

/*
Ejemplo de ejecucion:

-- Primero se prepara @inXml con el XML completo.
DECLARE @outResultCode INT;
EXEC dbo.sp_CargarCatalogos
    @inXml = @inXml,
    @outResultCode = @outResultCode OUTPUT;
SELECT @outResultCode AS CodigoResultado;
*/

-------------------------------------------------------------------------------------------
CREATE PROCEDURE dbo.sp_CargarCatalogos
    @inXml XML,
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ver si se recibio un XML.
    IF @inXml IS NULL
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- ver si existen los cinco catalogos.
    IF NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/Catalogos/Tipo_Doc/TipoDocuIdentidad'
        ) AS T(Nodo)
    )
    OR NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/Catalogos/Tipo_Moneda/TipoMoneda'
        ) AS T(Nodo)
    )
    OR NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/Catalogos/Parentezcos/Parentezco'
        ) AS T(Nodo)
    )
    OR NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/Catalogos/Tipo_Cuenta_Ahorros/TipoCuentaAhorro'
        ) AS T(Nodo)
    )
    OR NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/Catalogos/TipoOperacionesBitacora/TipoOperacion'
        ) AS T(Nodo)
    )
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    BEGIN TRY

        -- Iniciar la transaccion.
        BEGIN TRANSACTION;

        -- Cargar los tipos de documento.
        INSERT INTO dbo.TipoDocuIdentidad (Id, Nombre)
        SELECT
            T.Nodo.value('@Id', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(64)')
        FROM @inXml.nodes(
            '/Catalogos/Tipo_Doc/TipoDocuIdentidad'
        ) AS T(Nodo);

        -- Cargar los tipos de moneda.
        INSERT INTO dbo.TipoMoneda (Id, Nombre, Simbolo)
        SELECT
            T.Nodo.value('@Id', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(32)'),
            T.Nodo.value('@Simbolo', 'NVARCHAR(4)')
        FROM @inXml.nodes(
            '/Catalogos/Tipo_Moneda/TipoMoneda'
        ) AS T(Nodo);
    
        -- Cargar los parentescos.
        INSERT INTO dbo.Parentezco (Id, Nombre)
        SELECT
            T.Nodo.value('@Id', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(32)')
        FROM @inXml.nodes(
            '/Catalogos/Parentezcos/Parentezco'
        ) AS T(Nodo);
    
        -- Cargar los tipos de cuentas de ahorro.
        INSERT INTO dbo.TipoCuentaAhorro (
            Id,
            Nombre,
            IdTipoMoneda,
            SaldoMinimo,
            MultaSaldoMin,
            CargoAnual,
            NumRetirosHumano,
            NumRetirosAutomatico,
            ComisionHumano,
            ComisionAutomatico,
            Interes
        )
        SELECT
            T.Nodo.value('@Id', 'INT'),
            T.Nodo.value('@Nombre', 'VARCHAR(64)'),
            T.Nodo.value('@IdTipoMoneda', 'INT'),
            T.Nodo.value('@SaldoMinimo', 'DECIMAL(18,2)'),
            T.Nodo.value('@MultaSaldoMin', 'DECIMAL(18,2)'),
            T.Nodo.value('@CargoAnual', 'DECIMAL(18,2)'),
            T.Nodo.value('@NumRetirosHumano', 'INT'),
            T.Nodo.value('@NumRetirosAutomatico', 'INT'),
            T.Nodo.value('@comisionHumano', 'DECIMAL(18,2)'),
            T.Nodo.value('@comisionAutomatico', 'DECIMAL(18,2)'),
            T.Nodo.value('@interes', 'DECIMAL(5,2)')
        FROM @inXml.nodes(
            '/Catalogos/Tipo_Cuenta_Ahorros/TipoCuentaAhorro'
        ) AS T(Nodo);
    
        -- Carga los tipos de operaciones de bitacora
        INSERT INTO dbo.TipoOperacionBitacora (Id, Nombre)
        SELECT
            T.Nodo.value('@id', 'INT'),
            T.Nodo.value('@nombre', 'VARCHAR(64)')
        FROM @inXml.nodes(
            '/Catalogos/TipoOperacionesBitacora/TipoOperacion'
        ) AS T(Nodo);

        -- Confirma los cambios
        COMMIT TRANSACTION;
        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH

        -- Deshace los cambios si hay una transaccion abierta
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;
        SET @outResultCode = 50000;
    END CATCH
END;
GO


--------------------------------------------------------------------------------
-- Procedimiento para cargar las entidades desde XML.
CREATE PROCEDURE dbo.sp_CargarNoCatalogos
    @inXml XML,
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @inXml IS NULL
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- Ver si que existen las seis secciones del XML.
    IF NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/NoCatalogos/Personas/Persona'
        ) AS T(Nodo)
    )
    OR NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/NoCatalogos/Cuentas/Cuenta'
        ) AS T(Nodo)
    )
    OR NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/NoCatalogos/Beneficiarios/Beneficiario'
        ) AS T(Nodo)
    )
    OR NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/NoCatalogos/Estados_de_Cuenta/Estado_de_Cuenta'
        ) AS T(Nodo)
    )
    OR NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/NoCatalogos/Usuarios/Usuario'
        ) AS T(Nodo)
    )
    OR NOT EXISTS (
        SELECT 1
        FROM @inXml.nodes(
            '/NoCatalogos/Usuarios_Ver/UsuarioPuedeVer'
        ) AS T(Nodo)
    )
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Cargar las personas
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
            '/NoCatalogos/Personas/Persona'
        ) AS T(Nodo);


        -- Cargar el primer telefono de cada persona
        INSERT INTO dbo.Telefono (IdPersona, Numero)
        SELECT
            P.Id,
            T.Nodo.value('@telefono1', 'VARCHAR(16)')
        FROM @inXml.nodes(
            '/NoCatalogos/Personas/Persona'
        ) AS T(Nodo)
        INNER JOIN dbo.Persona P
            ON P.ValorDocumentoIdentidad =
               T.Nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(32)');


        -- Cargar el segundo telefono de cada persona
        INSERT INTO dbo.Telefono (IdPersona, Numero)
        SELECT
            P.Id,
            T.Nodo.value('@telefono2', 'VARCHAR(16)')
        FROM @inXml.nodes(
            '/NoCatalogos/Personas/Persona'
        ) AS T(Nodo)
        INNER JOIN dbo.Persona P
            ON P.ValorDocumentoIdentidad =
               T.Nodo.value('@ValorDocumentoIdentidad', 'VARCHAR(32)');


        -- Cargar las cuentas bancarias
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
            '/NoCatalogos/Cuentas/Cuenta'
        ) AS T(Nodo)
        INNER JOIN dbo.Persona P
            ON P.ValorDocumentoIdentidad =
               T.Nodo.value('@ValorDocumentoIdentidadDelCliente',
                            'VARCHAR(32)');

        
        -- Cargar los beneficiarios de cada cuenta.
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
            '/NoCatalogos/Beneficiarios/Beneficiario'
        ) AS T(Nodo)
        INNER JOIN dbo.Cuenta C
            ON C.NumeroCuenta =
               T.Nodo.value('@NumeroCuenta', 'VARCHAR(16)')
        INNER JOIN dbo.Persona P
            ON P.ValorDocumentoIdentidad =
               T.Nodo.value('@ValorDocumentoIdentidadBeneficiario',
                            'VARCHAR(32)');

       
        -- Cargar los estados de cuenta.
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
            CantSinpeSalientes
        )
        SELECT
            C.Id,
            T.Nodo.value('@fechaInicio', 'DATE'),
            T.Nodo.value('@fechafin', 'DATE'),
            T.Nodo.value('@saldoinicial', 'DECIMAL(18,2)'),
            T.Nodo.value('@saldoMinimo', 'DECIMAL(18,2)'),
            T.Nodo.value('@saldo_final', 'DECIMAL(18,2)'),
            T.Nodo.value('@interesesAcumulados', 'DECIMAL(18,2)'),
            T.Nodo.value('@cantRetiros', 'INT'),
            T.Nodo.value('@cantDepositos', 'INT'),
            T.Nodo.value('@cantSinpeEntrantes', 'INT'),
            T.Nodo.value('@cantSinpeSalientes', 'INT')
        FROM @inXml.nodes(
            '/NoCatalogos/Estados_de_Cuenta/Estado_de_Cuenta'
        ) AS T(Nodo)
        INNER JOIN dbo.Cuenta C
            ON C.NumeroCuenta =
               T.Nodo.value('@NumeroCuenta', 'VARCHAR(16)');


        -- Cargar los usuarios.
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
            '/NoCatalogos/Usuarios/Usuario'
        ) AS T(Nodo)
        INNER JOIN dbo.Persona P
            ON P.ValorDocumentoIdentidad =
               T.Nodo.value('@ValorDocId', 'VARCHAR(32)');

        
        -- Cargar los permisos de acceso a cuentas.
        INSERT INTO dbo.UsuarioPuedeVer (
            IdUsuario,
            IdCuenta
        )
        SELECT
            U.Id,
            C.Id
        FROM @inXml.nodes(
            '/NoCatalogos/Usuarios_Ver/UsuarioPuedeVer'
        ) AS T(Nodo)
        INNER JOIN dbo.Usuario U
            ON U.NombreUsuario =
               T.Nodo.value('@User', 'VARCHAR(64)')
        INNER JOIN dbo.Cuenta C
            ON C.NumeroCuenta =
               T.Nodo.value('@NumeroCuenta', 'VARCHAR(16)');

        

        -- Comprobar que se cargaron todos los registros del XML.
        IF (SELECT COUNT(*) FROM dbo.Persona) <>
           (SELECT COUNT(*)
            FROM @inXml.nodes('/NoCatalogos/Personas/Persona') AS T(Nodo))

        OR (SELECT COUNT(*) FROM dbo.Telefono) <>
           2 * (SELECT COUNT(*)
                FROM @inXml.nodes('/NoCatalogos/Personas/Persona') AS T(Nodo))

        OR (SELECT COUNT(*) FROM dbo.Cuenta) <>
           (SELECT COUNT(*)
            FROM @inXml.nodes('/NoCatalogos/Cuentas/Cuenta') AS T(Nodo))

        OR (SELECT COUNT(*) FROM dbo.Beneficiario) <>
           (SELECT COUNT(*)
            FROM @inXml.nodes('/NoCatalogos/Beneficiarios/Beneficiario') AS T(Nodo))

        OR (SELECT COUNT(*) FROM dbo.EstadoCuenta) <>
           (SELECT COUNT(*)
            FROM @inXml.nodes('/NoCatalogos/Estados_de_Cuenta/Estado_de_Cuenta') AS T(Nodo))

        OR (SELECT COUNT(*) FROM dbo.Usuario) <>
           (SELECT COUNT(*)
            FROM @inXml.nodes('/NoCatalogos/Usuarios/Usuario') AS T(Nodo))

        OR (SELECT COUNT(*) FROM dbo.UsuarioPuedeVer) <>
           (SELECT COUNT(*)
            FROM @inXml.nodes('/NoCatalogos/Usuarios_Ver/UsuarioPuedeVer') AS T(Nodo))

        BEGIN
            ROLLBACK TRANSACTION;
            SET @outResultCode = 50007;
            RETURN;
        END;


        COMMIT TRANSACTION;
        SET @outResultCode = 0;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @outResultCode = 50000;
    END CATCH
END;
GO
