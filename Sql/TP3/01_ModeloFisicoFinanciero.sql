
/* Tercera Tarea Programada - TP3
se adapto el modelo para la tp3, aqui se cambia el nombre de 4 columnas por las que se suan
en el xml de la tarea 3
*/

USE CuentaAhorrosTP2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.TipoCuentaAhorro', 'U') IS NULL
    BEGIN
        THROW 50010,
            'No existe la tabla TipoCuentaAhorro.',
            1;
    END;

    DECLARE @idTabla INT;
    DECLARE @columnasTP2 INT;
    DECLARE @columnasTP3 INT;

    SET @idTabla = OBJECT_ID('dbo.TipoCuentaAhorro');

    SELECT @columnasTP2 = COUNT(*)
    FROM sys.columns
    WHERE object_id = @idTabla
      AND name IN (
          'CargoAnual',
          'Interes',
          'SinpeMontoMaxDiarioSinComision',
          'SinpeComisionExceso'
      );

    SELECT @columnasTP3 = COUNT(*)
    FROM sys.columns
    WHERE object_id = @idTabla
      AND name IN (
          'CargoMensual',
          'TasaInteresAnual',
          'MontoMaxSinpeDiario',
          'ComisionSinpe'
      );

    IF @columnasTP2 = 4 AND @columnasTP3 = 0
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM sys.check_constraints
            WHERE parent_object_id = @idTabla
              AND name = 'CK_TipoCuentaAhorro_Montos'
        )
        BEGIN
            THROW 50011,
                'No existe la restriccion original de montos.',
                1;
        END;

        ALTER TABLE dbo.TipoCuentaAhorro
        DROP CONSTRAINT CK_TipoCuentaAhorro_Montos;


        EXEC sys.sp_rename
            'dbo.TipoCuentaAhorro.CargoAnual',
            'CargoMensual',
            'COLUMN';

        EXEC sys.sp_rename
            'dbo.TipoCuentaAhorro.Interes',
            'TasaInteresAnual',
            'COLUMN';

        EXEC sys.sp_rename
            'dbo.TipoCuentaAhorro.SinpeMontoMaxDiarioSinComision',
            'MontoMaxSinpeDiario',
            'COLUMN';

        EXEC sys.sp_rename
            'dbo.TipoCuentaAhorro.SinpeComisionExceso',
            'ComisionSinpe',
            'COLUMN';

        -- Recrear la restriccion con los nombres nuevos.
        EXEC (N'
            ALTER TABLE dbo.TipoCuentaAhorro
            WITH CHECK ADD CONSTRAINT CK_TipoCuentaAhorro_Montos
            CHECK (
                SaldoMinimo >= 0
                AND MultaSaldoMin >= 0
                AND CargoMensual >= 0
                AND NumRetirosHumano >= 0
                AND NumRetirosAutomatico >= 0
                AND ComisionHumano >= 0
                AND ComisionAutomatico >= 0
                AND TasaInteresAnual >= 0
                AND (
                    MontoMaxSinpeDiario IS NULL
                    OR MontoMaxSinpeDiario >= 0
                )
                AND (
                    ComisionSinpe IS NULL
                    OR ComisionSinpe >= 0
                )
            );
        ');
    END
    ELSE IF @columnasTP2 = 0 AND @columnasTP3 = 4
    BEGIN
        -- La migracion ya fue aplicada.
        PRINT 'Las columnas TP3 ya existen.';
    END
    ELSE
    BEGIN
        THROW 50012,
            'El esquema tiene columnas faltantes o una migracion parcial.',
            1;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.check_constraints
        WHERE parent_object_id = @idTabla
          AND name = 'CK_TipoCuentaAhorro_Montos'
          AND is_disabled = 0
          AND is_not_trusted = 0
    )
    BEGIN
        THROW 50013,
            'La restriccion de montos no esta correctamente habilitada.',
            1;
    END;

    COMMIT TRANSACTION;

    PRINT 'Migracion TipoCuentaAhorro completada.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;
GO



/*
Puse contadores de operaciones, ertiros de ATM y cajero
*/

SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.EstadoCuenta', 'U') IS NULL
    BEGIN
        THROW 50014,
            'No existe la tabla EstadoCuenta.',
            1;
    END;

    IF COL_LENGTH('dbo.EstadoCuenta',
                  'CantOperacionesATM') IS NULL
    BEGIN
        ALTER TABLE dbo.EstadoCuenta
        ADD CantOperacionesATM INT NULL
            CONSTRAINT DF_EstadoCuenta_OperacionesATM
            DEFAULT (0);
    END;

    IF COL_LENGTH('dbo.EstadoCuenta',
                  'CantRetirosATM') IS NULL
    BEGIN
        ALTER TABLE dbo.EstadoCuenta
        ADD CantRetirosATM INT NULL
            CONSTRAINT DF_EstadoCuenta_RetirosATM
            DEFAULT (0);
    END;

    IF COL_LENGTH('dbo.EstadoCuenta',
                  'CantOperacionesHumano') IS NULL
    BEGIN
        ALTER TABLE dbo.EstadoCuenta
        ADD CantOperacionesHumano INT NULL
            CONSTRAINT DF_EstadoCuenta_OperacionesHumano
            DEFAULT (0);
    END;

    IF COL_LENGTH('dbo.EstadoCuenta',
                  'CantRetirosHumano') IS NULL
    BEGIN
        ALTER TABLE dbo.EstadoCuenta
        ADD CantRetirosHumano INT NULL
            CONSTRAINT DF_EstadoCuenta_RetirosHumano
            DEFAULT (0);
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.check_constraints
        WHERE parent_object_id =
              OBJECT_ID('dbo.EstadoCuenta')
          AND name = 'CK_EstadoCuenta_OperacionesTP3'
    )
    BEGIN
        EXEC (N'
            ALTER TABLE dbo.EstadoCuenta
            WITH CHECK ADD CONSTRAINT
                CK_EstadoCuenta_OperacionesTP3
            CHECK (
                (
                    (CantOperacionesATM IS NULL
                     AND CantRetirosATM IS NULL)
                    OR
                    (CantOperacionesATM >= 0
                     AND CantRetirosATM >= 0
                     AND CantRetirosATM <= CantOperacionesATM)
                )
                AND
                (
                    (CantOperacionesHumano IS NULL
                     AND CantRetirosHumano IS NULL)
                    OR
                    (CantOperacionesHumano >= 0
                     AND CantRetirosHumano >= 0
                     AND CantRetirosHumano <= CantOperacionesHumano)
                )
            );
        ');
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sys.check_constraints
        WHERE parent_object_id =
              OBJECT_ID('dbo.EstadoCuenta')
          AND name = 'CK_EstadoCuenta_OperacionesTP3'
          AND is_disabled = 0
          AND is_not_trusted = 0
    )
    BEGIN
        THROW 50015,
            'La restriccion de operaciones TP3 no esta activa o es no confiable.',
            1;
    END;

    COMMIT TRANSACTION;

    PRINT 'Migracion EstadoCuenta completada.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO




/*
crear la tabla de tipo de movimiento con las verificacionesc oorespondientes
*/

SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.TipoMovimiento', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.TipoMovimiento
        (
            Id INT NOT NULL,
            Nombre VARCHAR(64) NOT NULL,
            Accion VARCHAR(7) NOT NULL,
            flagGeneraComprobante BIT NOT NULL,

            CONSTRAINT PK_TipoMovimiento
                PRIMARY KEY (Id),

            CONSTRAINT UQ_TipoMovimiento_Nombre
                UNIQUE (Nombre),

            CONSTRAINT CK_TipoMovimiento_Id
                CHECK (Id > 0),

            CONSTRAINT CK_TipoMovimiento_Accion
                CHECK (Accion IN ('Credito', 'Debito'))
        );
    END;

    IF (
        SELECT COUNT(*)
        FROM sys.columns
        WHERE object_id = OBJECT_ID('dbo.TipoMovimiento')
          AND name IN (
              'Id',
              'Nombre',
              'Accion',
              'flagGeneraComprobante'
          )
    ) <> 4
    BEGIN
        THROW 50016,
            'La estructura de TipoMovimiento no es la esperada.',
            1;
    END;

    COMMIT TRANSACTION;

    PRINT 'TipoMovimiento creada o verificada.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO





/*
creacion de la tabla de movimientos financieros de los estados de cuenta
*/

SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID('dbo.Movimiento', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.Movimiento
        (
            Id INT IDENTITY(1,1) NOT NULL,
            IdEstadoCuenta INT NOT NULL,
            IdTipoMovimiento INT NOT NULL,
            FechaMovimiento DATE NOT NULL,
            Monto DECIMAL(18,2) NOT NULL,
            Descripcion NVARCHAR(256) NOT NULL,
            SaldoPosterior DECIMAL(18,2) NOT NULL,
            ReferenciaOrigen VARCHAR(128) NOT NULL,
            SecuenciaOrigen TINYINT NOT NULL,

            CONSTRAINT PK_Movimiento
                PRIMARY KEY (Id),

            CONSTRAINT FK_Movimiento_EstadoCuenta
                FOREIGN KEY (IdEstadoCuenta)
                REFERENCES dbo.EstadoCuenta(Id),

            CONSTRAINT FK_Movimiento_TipoMovimiento
                FOREIGN KEY (IdTipoMovimiento)
                REFERENCES dbo.TipoMovimiento(Id),

            CONSTRAINT UQ_Movimiento_Origen
                UNIQUE (ReferenciaOrigen, SecuenciaOrigen),

            CONSTRAINT CK_Movimiento_Monto
                CHECK (Monto > 0),

            CONSTRAINT CK_Movimiento_SaldoPosterior
                CHECK (SaldoPosterior >= 0),

            CONSTRAINT CK_Movimiento_Referencia
                CHECK (LEN(LTRIM(RTRIM(ReferenciaOrigen))) > 0),

            CONSTRAINT CK_Movimiento_Secuencia
                CHECK (SecuenciaOrigen > 0)
        );
    END;

    IF (
        SELECT COUNT(*)
        FROM sys.columns
        WHERE object_id = OBJECT_ID('dbo.Movimiento')
          AND name IN (
              'Id',
              'IdEstadoCuenta',
              'IdTipoMovimiento',
              'FechaMovimiento',
              'Monto',
              'Descripcion',
              'SaldoPosterior',
              'ReferenciaOrigen',
              'SecuenciaOrigen'
          )
    ) <> 9
    BEGIN
        THROW 50017,
            'La estructura de Movimiento no es la esperada.',
            1;
    END;

    COMMIT TRANSACTION;

    PRINT 'Tabla Movimiento creada o verificada.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
