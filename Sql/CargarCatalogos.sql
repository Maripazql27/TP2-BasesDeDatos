
USE CuentaAhorrosTP2;
GO

-- Procedimiento para cargar los catalogos desde XML.
/*
Ejemplo de ejecucion:

-- Primero se prepara @inXml con el XML completo.
DECLARE @outResultCode INT;
EXEC dbo.sp_CargarCatalogos
    @inXml = @inXml,
    @outResultCode = @outResultCode OUTPUT;
SELECT @outResultCode AS CodigoResultado;
*/

CREATE PROCEDURE dbo.sp_CargarCatalogos
    @inXml XML,
    @outResultCode INT OUTPUT

AS
BEGIN
    -- Verificar que se recibio un XML.
    IF @inXml IS NULL
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- Verificar que existan los cinco catalogos.
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


    
        -- Cargar los tipos de operaciones de bitacora.
        INSERT INTO dbo.TipoOperacionBitacora (Id, Nombre)
        SELECT
            T.Nodo.value('@id', 'INT'),
            T.Nodo.value('@nombre', 'VARCHAR(64)')
        FROM @inXml.nodes(
            '/Catalogos/TipoOperacionesBitacora/TipoOperacion'
        ) AS T(Nodo);



        -- Confirmar los cambios.
        COMMIT TRANSACTION;

        SET @outResultCode = 0;

    END TRY


    BEGIN CATCH

        -- Deshacer los cambios si hay una transaccion abierta.
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        SET @outResultCode = 50000;

    END CATCH

END;
GO

