USE CuentaAhorrosTP2;
GO

/*
TP3 - sp_CargarCatalogos
Carga los catalogos del XML de la tarea 3 (CatalogosTarea3.xml).
Reemplaza al sp_CargarCatalogos de TP2, que ya no sirve porque
TipoCuentaAhorro cambio de columnas y ahora hay TipoMovimiento.

Orden de instalacion: CreaBasesTablas (TP2) -> 01_ModeloFisicoFinanciero
-> ErrorBD (bdpermisos.sql, parte 1) -> este script.

Entrada : @inXml  XML con el nodo raiz <Catalogos>
Salida  : @outResultCode
            0     = exito
            50007 = XML nulo o con secciones faltantes
            50300 = los catalogos ya estaban cargados
            50000 = error inesperado (queda en dbo.ErrorBD)

Ejemplo de ejecucion:
DECLARE @outResultCode INT;
EXEC dbo.sp_CargarCatalogos
    @inXml = @inXml,
    @outResultCode = @outResultCode OUTPUT;
SELECT @outResultCode AS CodigoResultado;
*/

CREATE OR ALTER PROCEDURE dbo.sp_CargarCatalogos
    @inXml XML
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @outResultCode = 0;

    -- Validaciones: que llegue el XML con las seis secciones.
    IF @inXml IS NULL
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1
                   FROM @inXml.nodes('/Catalogos/Tipo_Doc/TipoDocuIdentidad') AS T(Nodo))
       OR NOT EXISTS (SELECT 1
                      FROM @inXml.nodes('/Catalogos/Tipo_Moneda/TipoMoneda') AS T(Nodo))
       OR NOT EXISTS (SELECT 1
                      FROM @inXml.nodes('/Catalogos/Parentezcos/Parentezco') AS T(Nodo))
       OR NOT EXISTS (SELECT 1
                      FROM @inXml.nodes('/Catalogos/Tipo_Cuenta_Ahorros/TipoCuentaAhorro') AS T(Nodo))
       OR NOT EXISTS (SELECT 1
                      FROM @inXml.nodes('/Catalogos/Tipos_Movimiento/TipoMovimiento') AS T(Nodo))
       OR NOT EXISTS (SELECT 1
                      FROM @inXml.nodes('/Catalogos/TipoOperacionesBitacora/TipoOperacion') AS T(Nodo))
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- Los catalogos se cargan una sola vez.
    IF EXISTS (SELECT 1 FROM dbo.TipoDocuIdentidad)
       OR EXISTS (SELECT 1 FROM dbo.TipoMoneda)
       OR EXISTS (SELECT 1 FROM dbo.Parentezco)
       OR EXISTS (SELECT 1 FROM dbo.TipoCuentaAhorro)
       OR EXISTS (SELECT 1 FROM dbo.TipoMovimiento)
       OR EXISTS (SELECT 1 FROM dbo.TipoOperacionBitacora)
    BEGIN
        SET @outResultCode = 50300;
        RETURN;
    END;

    -- Hay varias inserciones: van juntas en una transaccion, al final del SP.
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TipoDocuIdentidad (Id, Nombre)
        SELECT
            T.Nodo.value('@Id', 'INT')
            , T.Nodo.value('@Nombre', 'VARCHAR(64)')
        FROM @inXml.nodes('/Catalogos/Tipo_Doc/TipoDocuIdentidad') AS T(Nodo);

        INSERT INTO dbo.TipoMoneda (Id, Nombre, Simbolo)
        SELECT
            T.Nodo.value('@Id', 'INT')
            , T.Nodo.value('@Nombre', 'VARCHAR(32)')
            , T.Nodo.value('@Simbolo', 'NVARCHAR(4)')
        FROM @inXml.nodes('/Catalogos/Tipo_Moneda/TipoMoneda') AS T(Nodo);

        INSERT INTO dbo.Parentezco (Id, Nombre)
        SELECT
            T.Nodo.value('@Id', 'INT')
            , T.Nodo.value('@Nombre', 'VARCHAR(32)')
        FROM @inXml.nodes('/Catalogos/Parentezcos/Parentezco') AS T(Nodo);

        INSERT INTO dbo.TipoCuentaAhorro (
            Id
            , Nombre
            , IdTipoMoneda
            , SaldoMinimo
            , MultaSaldoMin
            , CargoMensual
            , NumRetirosHumano
            , NumRetirosAutomatico
            , ComisionHumano
            , ComisionAutomatico
            , TasaInteresAnual
            , MontoMaxSinpeDiario
            , ComisionSinpe
        )
        SELECT
            T.Nodo.value('@Id', 'INT')
            , T.Nodo.value('@Nombre', 'VARCHAR(64)')
            , T.Nodo.value('@IdTipoMoneda', 'INT')
            , T.Nodo.value('@SaldoMinimo', 'DECIMAL(18,2)')
            , T.Nodo.value('@MultaSaldoMin', 'DECIMAL(18,2)')
            , T.Nodo.value('@CargoMensual', 'DECIMAL(18,2)')
            , T.Nodo.value('@NumRetirosHumano', 'INT')
            , T.Nodo.value('@NumRetirosAutomatico', 'INT')
            , T.Nodo.value('@ComisionHumano', 'DECIMAL(18,2)')
            , T.Nodo.value('@ComisionAutomatico', 'DECIMAL(18,2)')
            , T.Nodo.value('@TasaInteresAnual', 'DECIMAL(5,2)')
            , T.Nodo.value('@MontoMaxSinpeDiario', 'DECIMAL(18,2)')
            , T.Nodo.value('@ComisionSinpe', 'DECIMAL(18,2)')
        FROM @inXml.nodes('/Catalogos/Tipo_Cuenta_Ahorros/TipoCuentaAhorro') AS T(Nodo);

        INSERT INTO dbo.TipoMovimiento (Id, Nombre, Accion, flagGeneraComprobante)
        SELECT
            T.Nodo.value('@Id', 'INT')
            , T.Nodo.value('@Nombre', 'VARCHAR(64)')
            , T.Nodo.value('@Accion', 'VARCHAR(7)')
            , T.Nodo.value('@flagGeneraComprobante', 'BIT')
        FROM @inXml.nodes('/Catalogos/Tipos_Movimiento/TipoMovimiento') AS T(Nodo);

        INSERT INTO dbo.TipoOperacionBitacora (Id, Nombre)
        SELECT
            T.Nodo.value('@Id', 'INT')
            , T.Nodo.value('@Nombre', 'VARCHAR(64)')
        FROM @inXml.nodes('/Catalogos/TipoOperacionesBitacora/TipoOperacion') AS T(Nodo);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        -- El error se guarda aqui mismo (sin llamar a otro SP), ya fuera de la transaccion.
        INSERT INTO dbo.ErrorBD (
            NumeroError
            , Severidad
            , Estado
            , Procedimiento
            , Linea
            , Mensaje
        )
        VALUES (
            ERROR_NUMBER()
            , ERROR_SEVERITY()
            , ERROR_STATE()
            , ERROR_PROCEDURE()
            , ERROR_LINE()
            , ERROR_MESSAGE()
        );

        SET @outResultCode = 50000;
    END CATCH;
END;
GO