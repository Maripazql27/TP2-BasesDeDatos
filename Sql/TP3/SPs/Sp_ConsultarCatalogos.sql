
USE CuentaAhorrosTP2;
GO

/*
Ejemplo de ejecucion:

DECLARE @outResultCode INT;

EXEC dbo.sp_ListarParentezcos
    @outResultCode = @outResultCode OUTPUT;

SELECT @outResultCode AS CodigoResultado;
*/

CREATE PROCEDURE dbo.sp_ListarParentezcos
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Consulta los parentescos disponibles
        SELECT Id,
               Nombre
        FROM dbo.Parentezco
        ORDER BY Id;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50000;
    END CATCH;
END;
GO
------------------------------------------------------------------------------------------------

/*
Ejemplo de ejecucion:

DECLARE @outResultCode INT;

EXEC dbo.sp_ListarTiposDocumento
    @outResultCode = @outResultCode OUTPUT;

SELECT @outResultCode AS CodigoResultado;
*/

CREATE PROCEDURE dbo.sp_ListarTiposDocumento
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Consulta los tipos de documento disponibles
        SELECT Id,
               Nombre
        FROM dbo.TipoDocuIdentidad
        ORDER BY Id;

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50000;
    END CATCH;
END;
GO
