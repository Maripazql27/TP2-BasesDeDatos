/*
   la simulacion no se repite, no brinca fechas
   y, si se corta, reanuda desde la ultima llave procesada.

   Se corre Simulacion_TP3.sql cuatro veces, cambiando SOLO las tres
   variables @prueba... que estan al inicio de ese script. Despues de cada
   corrida se ejecuta aqui la CONSULTA A. Al final, la CONSULTA B compara
   el resultado con el de la corrida completa sin cortes.

   PASO 0. Correr Limpiar_Datos_TP3.sql (deja todo en 0, tambien el control).

   PASO 1. Corte en un cierre. En Simulacion_TP3.sql:
              @pruebaFechaDetener           = '2026-04-01'
              @pruebaDetenerTrasMovimientos = NULL
              @pruebaDetenerTrasCierres     = 1
           El 2026-04-01 no tiene nodo en el XML, pero ese dia cierran dos
           cuentas: 11000001 (Id 1) y 11000002 (Id 2).
           Esperado en la CONSULTA A:
             - 31 fechas terminadas (2026-03-01 a 2026-03-31)
             - 2026-04-01: FlagTerminada 0, CantCierres 1,
               UltimaCuentaCerrada 1 (11000001)
             - Corrida 1: CodigoResultado 3 (detenida a proposito)

   PASO 2. Corte a mitad de los movimientos. En Simulacion_TP3.sql:
              @pruebaFechaDetener           = '2026-04-20'
              @pruebaDetenerTrasMovimientos = 3
              @pruebaDetenerTrasCierres     = NULL
           El 2026-04-20 tiene 5 movimientos; del 3 en adelante la cuenta
           11000005 pasa el limite SINPE diario y paga comision.
           Esperado en la CONSULTA A:
             - Mensaje "Reanudando la fecha 2026-04-01" en Messages
             - 2026-04-01: FlagTerminada 1, CantCierres 2, CantIntentos 2,
               UltimaCuentaCerrada 2 (11000002). La cuenta 1 NO se cerro dos
               veces.
             - 2026-04-20: FlagTerminada 0, UltimoMovimientoProcesado 3,
               CantMovimientosAplicados 3 de 5
             - Corrida 2: desde 2026-04-01, CodigoResultado 3

   PASO 3. Corrida normal: las tres variables @prueba... en NULL.
           Esperado: reanuda 2026-04-20 desde el movimiento 4 y llega a
           2026-06-30. Corrida 3: CodigoResultado 0 (completa).

   PASO 4. Correr Simulacion_TP3.sql otra vez, sin cambiar nada.
           Esperado: "Nada pendiente", no aplica nada.
           Corrida 4: CodigoResultado 1.

   PASO 5. CONSULTA B: todo debe salir OK.

   Los valores esperados de la CONSULTA B son los de la corrida completa
   del 17-nov-2026 (122 fechas, 100 movimientos, 27 cierres). Si se cambian
   las reglas financieras (por ejemplo el saldo minimo del primer mes),
   primero hay que hacer una corrida completa sin cortes y actualizar estos
   valores.
*/
USE CuentaAhorrosTP2;
GO

-- =====================================================================
-- CONSULTA A: estado del control despues de cada corrida
-- =====================================================================
SELECT
    CR.Id AS Corrida,
    CR.FechaDesde,
    CR.FechaHasta,
    CR.CantFechasTerminadas,
    CR.CodigoResultado,
    CR.Mensaje
FROM dbo.CorridaSimulacion AS CR
ORDER BY CR.Id;

SELECT
    (SELECT COUNT(*)
     FROM dbo.ControlSimulacion AS CS
     WHERE CS.FlagTerminada = 1)            AS FechasTerminadas,
    (SELECT MIN(CS.FechaOperacion)
     FROM dbo.ControlSimulacion AS CS
     WHERE CS.FlagTerminada = 0)            AS FechaAMedias;

SELECT
    CS.FechaOperacion,
    CS.FlagAltasProcesadas,
    CS.UltimoMovimientoProcesado,
    CS.CantMovimientosXml,
    CS.CantMovimientosAplicados,
    CS.CantMovimientosRechazados,
    CS.UltimaCuentaCerrada,
    C.NumeroCuenta AS NumeroUltimaCuentaCerrada,
    CS.CantCierres,
    CS.CantIntentos,
    CS.FlagTerminada,
    CS.IdCorridaSimulacion
FROM dbo.ControlSimulacion AS CS
LEFT OUTER JOIN dbo.Cuenta AS C
    ON C.Id = CS.UltimaCuentaCerrada
WHERE CS.FechaOperacion IN ('2026-03-31', '2026-04-01', '2026-04-20',
                            '2026-06-30')
ORDER BY CS.FechaOperacion;
GO

-- =====================================================================
-- CONSULTA B: comparacion con la corrida completa sin cortes
-- =====================================================================
DECLARE @cuentaEsperada TABLE (
    NumeroCuenta VARCHAR(16)   NOT NULL PRIMARY KEY,
    Saldo        DECIMAL(18,2) NOT NULL,
    Estados      INT           NOT NULL
);
DECLARE @tipoEsperado TABLE (
    Nombre   VARCHAR(64) NOT NULL PRIMARY KEY,
    Cantidad INT         NOT NULL
);

INSERT INTO @cuentaEsperada (NumeroCuenta, Saldo, Estados)
VALUES ('11000001',  594249.01, 4),
       ('11000002', 1863670.06, 4),
       ('11000003',  235740.42, 4),
       ('11000004',   14684.22, 4),
       ('11000005', 2071540.00, 4),
       ('21000001',    1516.24, 4),
       ('11000007', 1449066.54, 4),
       ('11000008',  177753.69, 4),
       ('11000009',  956886.88, 3),
       ('11000010',   57600.00, 2);

INSERT INTO @tipoEsperado (Nombre, Cantidad)
VALUES ('Cargo Servicio Mensual', 27),
       ('Comision Exceso ATM', 1),
       ('Comision Exceso Ventana', 1),
       ('Comision Sinpe', 4),
       ('Compra', 25),
       ('Deposito ATM', 2),
       ('Deposito Sinpe', 19),
       ('Deposito Ventana', 13),
       ('Intereses Mensuales', 17),
       ('Multa Saldo Minimo', 11),
       ('Retiro ATM', 16),
       ('Retiro Sinpe', 14),
       ('Retiro Ventana', 11);

-- B1. Saldo y cantidad de estados por cuenta
SELECT
    E.NumeroCuenta,
    E.Saldo AS SaldoEsperado,
    C.Saldo AS SaldoObtenido,
    E.Estados AS EstadosEsperados,
    (SELECT COUNT(*)
     FROM dbo.EstadoCuenta AS EC
     WHERE EC.IdCuenta = C.Id) AS EstadosObtenidos,
    CASE
        WHEN C.Saldo = E.Saldo
         AND (SELECT COUNT(*)
              FROM dbo.EstadoCuenta AS EC
              WHERE EC.IdCuenta = C.Id) = E.Estados
            THEN 'OK'
        ELSE 'DIFERENTE'
    END AS Resultado
FROM @cuentaEsperada AS E
LEFT OUTER JOIN dbo.Cuenta AS C
    ON C.NumeroCuenta = E.NumeroCuenta
ORDER BY E.NumeroCuenta;

-- B2. Cantidad de movimientos por tipo
SELECT
    T.Nombre AS TipoMovimiento,
    T.Cantidad AS Esperado,
    (SELECT COUNT(*)
     FROM dbo.Movimiento AS M
     INNER JOIN dbo.TipoMovimiento AS TM
         ON TM.Id = M.IdTipoMovimiento
     WHERE TM.Nombre = T.Nombre) AS Obtenido,
    CASE
        WHEN (SELECT COUNT(*)
              FROM dbo.Movimiento AS M
              INNER JOIN dbo.TipoMovimiento AS TM
                  ON TM.Id = M.IdTipoMovimiento
              WHERE TM.Nombre = T.Nombre) = T.Cantidad
            THEN 'OK'
        ELSE 'DIFERENTE'
    END AS Resultado
FROM @tipoEsperado AS T
ORDER BY T.Nombre;

-- B3. Totales: nada duplicado y nada saltado
SELECT
    'Movimientos en total (esperado 161)' AS Verificacion,
    (SELECT COUNT(*) FROM dbo.Movimiento) AS Obtenido,
    CASE WHEN (SELECT COUNT(*) FROM dbo.Movimiento) = 161
         THEN 'OK' ELSE 'DIFERENTE' END AS Resultado
UNION ALL
SELECT
    'Nodos Movimientos del XML aplicados una vez (esperado 100)',
    (SELECT COUNT(DISTINCT M.ReferenciaOrigen)
     FROM dbo.Movimiento AS M
     WHERE M.ReferenciaOrigen LIKE '2026-%#%'),
    CASE WHEN (SELECT COUNT(DISTINCT M.ReferenciaOrigen)
               FROM dbo.Movimiento AS M
               WHERE M.ReferenciaOrigen LIKE '2026-%#%') = 100
         THEN 'OK' ELSE 'DIFERENTE' END
UNION ALL
SELECT
    'Cierres distintos (esperado 27)',
    (SELECT COUNT(DISTINCT M.ReferenciaOrigen)
     FROM dbo.Movimiento AS M
     WHERE M.ReferenciaOrigen LIKE 'CIERRE:%'),
    CASE WHEN (SELECT COUNT(DISTINCT M.ReferenciaOrigen)
               FROM dbo.Movimiento AS M
               WHERE M.ReferenciaOrigen LIKE 'CIERRE:%') = 27
         THEN 'OK' ELSE 'DIFERENTE' END
UNION ALL
SELECT
    'Estados de cuenta (esperado 37)',
    (SELECT COUNT(*) FROM dbo.EstadoCuenta),
    CASE WHEN (SELECT COUNT(*) FROM dbo.EstadoCuenta) = 37
         THEN 'OK' ELSE 'DIFERENTE' END
UNION ALL
SELECT
    'Fechas terminadas (esperado 122)',
    (SELECT COUNT(*) FROM dbo.ControlSimulacion WHERE FlagTerminada = 1),
    CASE WHEN (SELECT COUNT(*)
               FROM dbo.ControlSimulacion
               WHERE FlagTerminada = 1) = 122
         THEN 'OK' ELSE 'DIFERENTE' END
UNION ALL
SELECT
    'Errores registrados (esperado 0)',
    (SELECT COUNT(*) FROM dbo.ErrorBD),
    CASE WHEN (SELECT COUNT(*) FROM dbo.ErrorBD) = 0
         THEN 'OK' ELSE 'DIFERENTE' END;
GO
