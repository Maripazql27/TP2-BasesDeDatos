USE CuentaAhorrosTP2;   -- base oficial (Persona 1)
GO

/* --------------------------------------------------------------------------
   sp_RegistrarError
   Guarda en dbo.ErrorBD los datos del error que se est? atendiendo en el
   CATCH que lo llam? (n?mero, severidad, estado, procedimiento donde ocurri?,
   l?nea y mensaje).

   Solo se debe llamar DENTRO de un bloque CATCH. Las funciones ERROR_NUMBER(),
   ERROR_MESSAGE(), etc. devuelven los datos del error original aunque se
   lean desde este procedimiento; fuera de un CATCH devuelven NULL.

   Entrada : ninguna
   Salida  : ninguna (no tiene @outResultCode: no debe fallar el CATCH)

   Uso:
     BEGIN CATCH
         EXEC dbo.sp_RegistrarError;
         SET @outResultCode = 50000;
     END CATCH;
   -------------------------------------------------------------------------- */
DROP PROCEDURE IF EXISTS dbo.sp_RegistrarError;
GO
CREATE PROCEDURE dbo.sp_RegistrarError
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ErrorBD
    (
        FechaHora
        , NumeroError
        , Severidad
        , Estado
        , Procedimiento
        , Linea
        , Mensaje
    )
    VALUES
    (
        SYSDATETIME()
        , ERROR_NUMBER()
        , ERROR_SEVERITY()
        , ERROR_STATE()
        , ERROR_PROCEDURE()
        , ERROR_LINE()
        , ERROR_MESSAGE()
    );
END
GO