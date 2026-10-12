/* ==========================================================================
   TP2 - Base de Datos 1 - Cuenta de Ahorros
   Script 04b: procedimiento común para registrar errores inesperados

   Todos los SP del grupo lo llaman desde su bloque CATCH. Así el INSERT en
   ErrorBD está escrito UNA sola vez y todos los errores se guardan igual.

   Requiere: la tabla dbo.ErrorBD (script 01 del grupo).
   ========================================================================== */
--USE CuentaAhorrosTP2; --conexion a base de datos real
USE PruebaTP2_Persona2 --conexion a base de datos de prueba
GO

/* --------------------------------------------------------------------------
   sp_RegistrarError
   Guarda en dbo.ErrorBD los datos del error que se está atendiendo en el
   CATCH que lo llamó (número, severidad, estado, procedimiento donde ocurrió,
   línea y mensaje).

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