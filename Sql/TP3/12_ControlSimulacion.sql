/*

   Para que:
     - el proceso masivo no se corre mas de una vez,
     - no se brinca una fecha (siempre se procesa la pendiente mas antigua),
     - si falla sin terminar, se reinicia desde la ultima llave procesada.

   dbo.CorridaSimulacion: una fila por cada vez que se ejecuta Simulacion_TP3.sql.
     CodigoResultado: 0 completa, 1 nada pendiente, 2 detenida por error
                      o interrumpida, 3 detenida a proposito (prueba).

   dbo.ControlSimulacion: una fila por fecha de operacion, con hasta donde se
   llego en esa fecha:
     FlagAltasProcesadas        altas del dia ya aplicadas
     UltimoMovimientoProcesado  posicion del ultimo nodo Movimientos procesado
                                (0 = ninguno todavia)
     UltimaCuentaCerrada        Id (PK) de la ultima cuenta cerrada ese dia
                                (0 = ninguna todavia)
     FlagTerminada              la fecha quedo completa

   Se puede correr varias veces: si las tablas ya existen, no hace nada.
   Orden de instalacion: despues de 01_ModeloFisicoFinanciero.sql y antes de
   correr Simulacion_TP3.sql.
*/
USE CuentaAhorrosTP2;
GO

IF OBJECT_ID('dbo.CorridaSimulacion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CorridaSimulacion (
        Id                   INT           IDENTITY(1,1) NOT NULL,
        FechaHoraInicio      DATETIME2(0)  NOT NULL
            CONSTRAINT DF_CorridaSimulacion_Inicio DEFAULT (SYSDATETIME()),
        FechaHoraFin         DATETIME2(0)  NULL,
        FechaInicioXml       DATE          NOT NULL,
        FechaFinXml          DATE          NOT NULL,
        FechaDesde           DATE          NULL,  -- primera fecha que trabajo
        FechaHasta           DATE          NULL,  -- ultima fecha que termino
        CantFechasTerminadas INT           NOT NULL
            CONSTRAINT DF_CorridaSimulacion_Cant DEFAULT (0),
        CodigoResultado      INT           NULL,
        Mensaje              NVARCHAR(256) NULL,
        CONSTRAINT PK_CorridaSimulacion PRIMARY KEY (Id)
    );
END;
GO

IF OBJECT_ID('dbo.ControlSimulacion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ControlSimulacion (
        Id                        INT          IDENTITY(1,1) NOT NULL,
        FechaOperacion            DATE         NOT NULL,
        IdCorridaSimulacion       INT          NOT NULL,  -- ultima corrida que la trabajo
        FlagAltasProcesadas       BIT          NOT NULL
            CONSTRAINT DF_ControlSimulacion_Altas DEFAULT (0),
        CantMovimientosXml        INT          NOT NULL
            CONSTRAINT DF_ControlSimulacion_MovXml DEFAULT (0),
        UltimoMovimientoProcesado INT          NOT NULL
            CONSTRAINT DF_ControlSimulacion_UltMov DEFAULT (0),
        CantMovimientosAplicados  INT          NOT NULL
            CONSTRAINT DF_ControlSimulacion_Aplicados DEFAULT (0),
        CantMovimientosRechazados INT          NOT NULL
            CONSTRAINT DF_ControlSimulacion_Rechazados DEFAULT (0),
        UltimaCuentaCerrada       INT          NOT NULL
            CONSTRAINT DF_ControlSimulacion_UltCuenta DEFAULT (0),
        CantCierres               INT          NOT NULL
            CONSTRAINT DF_ControlSimulacion_Cierres DEFAULT (0),
        CantIntentos              INT          NOT NULL
            CONSTRAINT DF_ControlSimulacion_Intentos DEFAULT (1),
        FlagTerminada             BIT          NOT NULL
            CONSTRAINT DF_ControlSimulacion_Terminada DEFAULT (0),
        CodigoError               INT          NULL,
        FechaHoraInicio           DATETIME2(0) NOT NULL
            CONSTRAINT DF_ControlSimulacion_Inicio DEFAULT (SYSDATETIME()),
        FechaHoraFin              DATETIME2(0) NULL,
        CONSTRAINT PK_ControlSimulacion PRIMARY KEY (Id),
        CONSTRAINT UQ_ControlSimulacion_Fecha UNIQUE (FechaOperacion),
        CONSTRAINT FK_ControlSimulacion_Corrida
            FOREIGN KEY (IdCorridaSimulacion)
            REFERENCES dbo.CorridaSimulacion (Id)
    );
END;
GO

-- Verificacion: deben salir las dos tablas
SELECT name AS TablaDeControl
FROM sys.tables
WHERE name IN ('CorridaSimulacion', 'ControlSimulacion')
ORDER BY name;
GO
