/*
   Solo lectura. Devuelve tres consultas, en este orden:
     1. Resumen: rango de fechas del XML, fechas terminadas, ultima fecha
        terminada, proxima fecha pendiente y totales de movimientos/cierres.
     2. Corridas de Simulacion_TP3.sql, de la mas reciente a la mas antigua.
     3. Fechas de operacion con su control, de la mas reciente a la mas
        antigua.
   No llama a otros SP. Los errores se guardan en dbo.ErrorBD desde aqui.

   Codigos de salida (@outResultCode):
     0      OK
     50000  error de SQL. Detalle en dbo.ErrorBD

   Ejemplo de ejecucion:
     DECLARE @r INT;
     EXEC dbo.sp_ConsultarControlSimulacion @outResultCode = @r OUTPUT;
     SELECT @r;
*/
USE CuentaAhorrosTP2;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ConsultarControlSimulacion
    @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Constantes
    DECLARE @true  BIT = 1;
    DECLARE @false BIT = 0;

    -- Variables
    DECLARE @fechaInicioXml DATE;
    DECLARE @fechaFinXml DATE;
    DECLARE @fechaPendiente DATE;

    SET @outResultCode = 0;

    BEGIN TRY
        -- Rango de fechas del XML, segun la ultima corrida
        SELECT TOP (1)
            @fechaInicioXml = CR.FechaInicioXml,
            @fechaFinXml    = CR.FechaFinXml
        FROM dbo.CorridaSimulacion AS CR
        ORDER BY CR.Id DESC;

        -- Proxima fecha pendiente: la mas antigua que no este terminada
        SET @fechaPendiente = @fechaInicioXml;

        WHILE (@fechaPendiente <= @fechaFinXml
               AND EXISTS (SELECT 1
                           FROM dbo.ControlSimulacion AS CS
                           WHERE CS.FechaOperacion = @fechaPendiente
                             AND CS.FlagTerminada = @true))
        BEGIN
            SET @fechaPendiente = DATEADD(DAY, 1, @fechaPendiente);
        END;

        IF (@fechaPendiente > @fechaFinXml)
        BEGIN
            SET @fechaPendiente = NULL;
        END;

        -- Resumen
        SELECT
            @fechaInicioXml AS FechaInicioXml,
            @fechaFinXml    AS FechaFinXml,
            ISNULL(DATEDIFF(DAY, @fechaInicioXml, @fechaFinXml) + 1, 0)
                            AS CantFechasXml,
            (SELECT COUNT(*)
             FROM dbo.ControlSimulacion AS CS
             WHERE CS.FlagTerminada = @true)        AS CantFechasTerminadas,
            (SELECT MAX(CS.FechaOperacion)
             FROM dbo.ControlSimulacion AS CS
             WHERE CS.FlagTerminada = @true)        AS UltimaFechaTerminada,
            @fechaPendiente                         AS ProximaFechaPendiente,
            (SELECT COUNT(*)
             FROM dbo.CorridaSimulacion AS CR)      AS CantCorridas,
            (SELECT ISNULL(SUM(CS.CantMovimientosAplicados), 0)
             FROM dbo.ControlSimulacion AS CS)      AS TotalMovimientosAplicados,
            (SELECT ISNULL(SUM(CS.CantMovimientosRechazados), 0)
             FROM dbo.ControlSimulacion AS CS)      AS TotalMovimientosRechazados,
            (SELECT ISNULL(SUM(CS.CantCierres), 0)
             FROM dbo.ControlSimulacion AS CS)      AS TotalCierres;

        -- Corridas
        SELECT
            CR.Id AS IdCorrida,
            CR.FechaHoraInicio,
            CR.FechaHoraFin,
            CR.FechaDesde,
            CR.FechaHasta,
            CR.CantFechasTerminadas,
            CR.CodigoResultado,
            CR.Mensaje
        FROM dbo.CorridaSimulacion AS CR
        ORDER BY CR.Id DESC;

        -- Fechas
        SELECT
            CS.FechaOperacion,
            CS.IdCorridaSimulacion,
            CS.FlagAltasProcesadas,
            CS.CantMovimientosXml,
            CS.UltimoMovimientoProcesado,
            CS.CantMovimientosAplicados,
            CS.CantMovimientosRechazados,
            CS.UltimaCuentaCerrada,
            C.NumeroCuenta AS NumeroUltimaCuentaCerrada,
            CS.CantCierres,
            CS.CantIntentos,
            CS.FlagTerminada,
            CS.CodigoError,
            CS.FechaHoraInicio,
            CS.FechaHoraFin
        FROM dbo.ControlSimulacion AS CS
        LEFT OUTER JOIN dbo.Cuenta AS C
            ON C.Id = CS.UltimaCuentaCerrada
        ORDER BY CS.FechaOperacion DESC;
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
