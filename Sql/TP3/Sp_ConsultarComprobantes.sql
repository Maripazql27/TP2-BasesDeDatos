/*
   Solo lectura. Lo usa el servidor web, solo para el administrador: la
   seccion "Comprobantes por correo" de la pagina de control y el envio de
   los correos pendientes. Devuelve dos consultas, en este orden:
     1. Resumen: comprobantes generados, enviados, pendientes y pendientes
        con algun intento de envio fallido.
     2. Comprobantes, del mas reciente al mas antiguo, con a quien van, el
        asunto, el texto del correo y el estado del envio. Con
        @inFlagSoloPendientes = 1 solo devuelve los que falta enviar.
   No llama a otros SP. Los errores se guardan en dbo.ErrorBD desde aqui.

   Codigos de salida (@outResultCode):
     0      OK
     50600  parametros invalidos
     50000  error de SQL. Detalle en dbo.ErrorBD

   Ejemplo de ejecucion:
     DECLARE @r INT;
     EXEC dbo.sp_ConsultarComprobantes
          @inFlagSoloPendientes = 0,
          @outResultCode = @r OUTPUT;
     SELECT @r;
*/
USE CuentaAhorrosTP2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ConsultarComprobantes
    @inFlagSoloPendientes BIT,
    @outResultCode        INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Constantes
    DECLARE @true  BIT = 1;
    DECLARE @false BIT = 0;

    SET @outResultCode = 0;

    -- Validaciones
    IF (@inFlagSoloPendientes IS NULL)
    BEGIN
        SET @outResultCode = 50600;
        RETURN;
    END;

    BEGIN TRY
        -- 1. Resumen
        SELECT
            COUNT(*) AS CantGenerados,
            ISNULL(SUM(CASE WHEN C.FlagEnviado = @true
                            THEN 1 ELSE 0 END), 0) AS CantEnviados,
            ISNULL(SUM(CASE WHEN C.FlagEnviado = @false
                            THEN 1 ELSE 0 END), 0) AS CantPendientes,
            ISNULL(SUM(CASE WHEN C.FlagEnviado = @false
                             AND C.CantIntentosEnvio > 0
                            THEN 1 ELSE 0 END), 0) AS CantConError
        FROM dbo.Comprobante AS C;

        -- 2. Comprobantes (todos, o solo los pendientes de enviar)
        SELECT
            C.Id AS IdComprobante,
            C.FechaOperacion,
            C.EmailDestino,
            C.Asunto,
            C.TextoEmail,
            C.FlagEnviado,
            C.CantIntentosEnvio,
            C.UltimoErrorEnvio,
            C.FechaHoraCreacion,
            C.FechaHoraEnvio
        FROM dbo.Comprobante AS C
        WHERE (@inFlagSoloPendientes = @false
               OR C.FlagEnviado = @false)
        ORDER BY C.Id DESC;
    END TRY
    BEGIN CATCH
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
