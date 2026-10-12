
USE CuentaAhorrosTP2;
GO

/*
Ejemplo de ejecucion:

DECLARE @outResultCode INT;

EXEC dbo.sp_RegistrarBitacora
    @inIdUsuario = 1,
    @inIdTipoOperacion = 1,
    @inIP = '127.0.0.1',
    @outResultCode = @outResultCode OUTPUT;

SELECT @outResultCode AS CodigoResultado;
*/

CREATE PROCEDURE dbo.sp_RegistrarBitacora
    @inIdUsuario INT,
    @inIdTipoOperacion INT,
    @inIP VARCHAR(45) = NULL,
    @inJsonAntes NVARCHAR(MAX) = NULL,
    @inJsonDespues NVARCHAR(MAX) = NULL,
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ver si existe el usuario
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Usuario
        WHERE Id = @inIdUsuario
    )
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- ver el tipo de operacion
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.TipoOperacionBitacora
        WHERE Id = @inIdTipoOperacion
    )
    BEGIN
        SET @outResultCode = 50008;
        RETURN;
    END;

    -- El login debe registrar una IP
    IF @inIdTipoOperacion = 1
       AND (@inIP IS NULL OR LTRIM(RTRIM(@inIP)) = '')
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- Agregar beneficiario requiere datos despues
    IF @inIdTipoOperacion = 3
       AND @inJsonDespues IS NULL
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- Actualizar y eliminar requieren los2 estados
    IF @inIdTipoOperacion IN (4, 5, 6)
       AND (@inJsonAntes IS NULL OR @inJsonDespues IS NULL)
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    -- Valida el formato de los JSON 
    IF ((@inJsonAntes IS NOT NULL
         AND ISJSON(@inJsonAntes) <> 1)
        OR (@inJsonDespues IS NOT NULL
            AND ISJSON(@inJsonDespues) <> 1))
    BEGIN
        SET @outResultCode = 50007;
        RETURN;
    END;

    BEGIN TRY
        INSERT INTO dbo.Bitacora (
            IdUsuario,
            IdTipoOperacion,
            IP,
            JsonAntes,
            JsonDespues
        )
        VALUES (
            @inIdUsuario,
            @inIdTipoOperacion,
            @inIP,
            @inJsonAntes,
            @inJsonDespues
        );

        SET @outResultCode = 0;
    END TRY
    BEGIN CATCH
        SET @outResultCode = 50000;
    END CATCH;
END;
GO
