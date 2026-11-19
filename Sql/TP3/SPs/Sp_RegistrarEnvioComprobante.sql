/*
   Registra el resultado de enviar por correo un comprobante. Lo llama el
   servidor web DESPUES de intentar el envio: el correo nunca se envia
   dentro de una transaccion de la base de datos, porque no se puede
   deshacer.
     @inFlagEnviado = 1: el correo salio; el comprobante queda enviado.
     @inFlagEnviado = 0: el envio fallo; el comprobante sigue pendiente (se
                         reintenta en el proximo envio), se cuenta el intento
                         y se guarda el mensaje de error.
   Un comprobante ya enviado no se vuelve a marcar: asi el servidor no lo
   envia dos veces.
   Es una sola actualizacion, por eso no usa una transaccion explicita.
   No llama a otros SP. Los errores se guardan en dbo.ErrorBD desde aqui.

   Codigos de salida (@outResultCode):
     0      OK
     50600  parametros invalidos
     50601  el comprobante no existe
     50602  el comprobante ya estaba enviado
     50000  error de SQL. Detalle en dbo.ErrorBD

   Ejemplo de ejecucion:
     DECLARE @r INT;
     EXEC dbo.sp_RegistrarEnvioComprobante
          @inIdComprobante = 1,
          @inFlagEnviado   = 1,
          @inMensajeError  = NULL,
          @outResultCode   = @r OUTPUT;
     SELECT @r;
*/
USE CuentaAhorrosTP2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RegistrarEnvioComprobante
    @inIdComprobante INT,
    @inFlagEnviado   BIT,
    @inMensajeError  NVARCHAR(400),
    @outResultCode   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Constantes
    DECLARE @true  BIT = 1;
    DECLARE @false BIT = 0;

    SET @outResultCode = 0;

    -- Validaciones
    IF (@inIdComprobante IS NULL OR @inFlagEnviado IS NULL)
    BEGIN
        SET @outResultCode = 50600;
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1
                   FROM dbo.Comprobante AS C
                   WHERE C.Id = @inIdComprobante)
    BEGIN
        SET @outResultCode = 50601;
        RETURN;
    END;

    IF EXISTS (SELECT 1
               FROM dbo.Comprobante AS C
               WHERE C.Id = @inIdComprobante
                 AND C.FlagEnviado = @true)
    BEGIN
        SET @outResultCode = 50602;
        RETURN;
    END;

    BEGIN TRY
        -- La condicion FlagEnviado = 0 evita marcarlo dos veces si otro
        -- proceso lo marco entre la validacion y esta actualizacion.
        UPDATE dbo.Comprobante
        SET FlagEnviado       = @inFlagEnviado,
            CantIntentosEnvio = CantIntentosEnvio + 1,
            UltimoErrorEnvio  = CASE
                                    WHEN @inFlagEnviado = @true THEN NULL
                                    ELSE ISNULL(@inMensajeError,
                                                N'Error sin detalle')
                                END,
            FechaHoraEnvio    = CASE
                                    WHEN @inFlagEnviado = @true
                                        THEN SYSDATETIME()
                                    ELSE NULL
                                END
        WHERE Id = @inIdComprobante
          AND FlagEnviado = @false;

        IF (@@ROWCOUNT = 0)
        BEGIN
            SET @outResultCode = 50602;
        END;
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
