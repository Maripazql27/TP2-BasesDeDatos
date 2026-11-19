/*
pruebas para verificar
*/

USE CuentaAhorrosTP2;
GO
SET NOCOUNT ON;

DECLARE @idEstado INT;
DECLARE @fechaPrueba DATE;
DECLARE @correctas INT = 0;
DECLARE @fallidas INT = 0;

SELECT TOP (1)
    @idEstado = Id,
    @fechaPrueba = FechaInicio
FROM dbo.EstadoCuenta
ORDER BY Id;

IF @idEstado IS NULL
BEGIN
    PRINT 'No hay estados de cuenta para realizar las pruebas.';
    RETURN;
END;

IF OBJECT_ID('dbo.TipoMovimiento', 'U') IS NULL
   OR OBJECT_ID('dbo.Movimiento', 'U') IS NULL
BEGIN
    PRINT 'Faltan las tablas TipoMovimiento o Movimiento.';
    RETURN;
END;

IF EXISTS (
    SELECT 1 FROM dbo.TipoMovimiento WHERE Id IN (900001, 900002)
)
OR EXISTS (
    SELECT 1 FROM dbo.Movimiento
    WHERE ReferenciaOrigen LIKE 'PRUEBA:P101:%'
)
BEGIN
    PRINT 'Se encontraron identificadores de prueba ocupados. No ejecutar.';
    RETURN;
END;

--Insercion valida de un tipo y de un movimiento. Se revierten ambas inserciones aunque sean correctas
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.TipoMovimiento
        (Id, Nombre, Accion, flagGeneraComprobante)
    VALUES
        (900001, 'Tipo Temporal Prueba TP3', 'Credito', 0);

    INSERT INTO dbo.Movimiento
        (IdEstadoCuenta, IdTipoMovimiento, FechaMovimiento,
         Monto, Descripcion, SaldoPosterior,
         ReferenciaOrigen, SecuenciaOrigen)
    VALUES
        (@idEstado, 900001, @fechaPrueba,
         100.00, N'Prueba estructural valida', 100.00,
         'PRUEBA:P101:001', 1);

    ROLLBACK TRANSACTION;
    SET @correctas = @correctas + 1;
    PRINT 'Prueba 1: insercion valida, revertida - OK';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SET @fallidas = @fallidas + 1;
    PRINT 'Prueba 1: ERROR - ' + ERROR_MESSAGE();
END CATCH;

--Impedir dos movimientos con misma referencia y secuencia
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.TipoMovimiento
        (Id, Nombre, Accion, flagGeneraComprobante)
    VALUES
        (900001, 'Tipo Temporal Prueba TP3', 'Credito', 0);

    INSERT INTO dbo.Movimiento
        (IdEstadoCuenta, IdTipoMovimiento, FechaMovimiento,
         Monto, Descripcion, SaldoPosterior,
         ReferenciaOrigen, SecuenciaOrigen)
    VALUES
        (@idEstado, 900001, @fechaPrueba,
         100.00, N'Primera operacion', 100.00,
         'PRUEBA:P101:002', 1);

    INSERT INTO dbo.Movimiento
        (IdEstadoCuenta, IdTipoMovimiento, FechaMovimiento,
         Monto, Descripcion, SaldoPosterior,
         ReferenciaOrigen, SecuenciaOrigen)
    VALUES
        (@idEstado, 900001, @fechaPrueba,
         50.00, N'Operacion duplicada', 150.00,
         'PRUEBA:P101:002', 1);

    ROLLBACK TRANSACTION;
    SET @fallidas = @fallidas + 1;
    PRINT 'Prueba 2: ERROR - se acepto una referencia duplicada.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    IF ERROR_NUMBER() IN (2601, 2627)
       AND ERROR_MESSAGE() LIKE '%UQ_Movimiento_Origen%'
    BEGIN
        SET @correctas = @correctas + 1;
        PRINT 'Prueba 2: duplicado rechazado - OK';
    END
    ELSE
    BEGIN
        SET @fallidas = @fallidas + 1;
        PRINT 'Prueba 2: ERROR inesperado - ' + ERROR_MESSAGE();
    END;
END CATCH;

--Rechazar monto igual a cero
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.TipoMovimiento
        (Id, Nombre, Accion, flagGeneraComprobante)
    VALUES
        (900001, 'Tipo Temporal Prueba TP3', 'Credito', 0);

    INSERT INTO dbo.Movimiento
        (IdEstadoCuenta, IdTipoMovimiento, FechaMovimiento,
         Monto, Descripcion, SaldoPosterior,
         ReferenciaOrigen, SecuenciaOrigen)
    VALUES
        (@idEstado, 900001, @fechaPrueba,
         0.00, N'Monto no permitido', 100.00,
         'PRUEBA:P101:003', 1);

    ROLLBACK TRANSACTION;
    SET @fallidas = @fallidas + 1;
    PRINT 'Prueba 3: ERROR - se acepto monto igual a cero.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    IF ERROR_NUMBER() = 547
       AND ERROR_MESSAGE() LIKE '%CK_Movimiento_Monto%'
    BEGIN
        SET @correctas = @correctas + 1;
        PRINT 'Prueba 3: monto cero rechazado - OK';
    END
    ELSE
    BEGIN
        SET @fallidas = @fallidas + 1;
        PRINT 'Prueba 3: ERROR inesperado - ' + ERROR_MESSAGE();
    END;
END CATCH;

--Rechazar un tipo de movimiento inexistente
BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.Movimiento
        (IdEstadoCuenta, IdTipoMovimiento, FechaMovimiento,
         Monto, Descripcion, SaldoPosterior,
         ReferenciaOrigen, SecuenciaOrigen)
    VALUES
        (@idEstado, 900002, @fechaPrueba,
         25.00, N'Tipo inexistente', 125.00,
         'PRUEBA:P101:004', 1);

    ROLLBACK TRANSACTION;
    SET @fallidas = @fallidas + 1;
    PRINT 'Prueba 4: ERROR - se acepto tipo inexistente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    IF ERROR_NUMBER() = 547
       AND ERROR_MESSAGE() LIKE '%FK_Movimiento_TipoMovimiento%'
    BEGIN
        SET @correctas = @correctas + 1;
        PRINT 'Prueba 4: tipo inexistente rechazado - OK';
    END
    ELSE
    BEGIN
        SET @fallidas = @fallidas + 1;
        PRINT 'Prueba 4: ERROR inesperado - ' + ERROR_MESSAGE();
    END;
END CATCH;

--Contadores ATM no pueden estar parcialmente NULL
BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.EstadoCuenta
       SET CantOperacionesATM = 1,
           CantRetirosATM = NULL
     WHERE Id = @idEstado;

    ROLLBACK TRANSACTION;
    SET @fallidas = @fallidas + 1;
    PRINT 'Prueba 5: ERROR - se aceptaron contadores invalidos.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    IF ERROR_NUMBER() = 547
       AND ERROR_MESSAGE() LIKE '%CK_EstadoCuenta_OperacionesTP3%'
    BEGIN
        SET @correctas = @correctas + 1;
        PRINT 'Prueba 5: contadores invalidos rechazados - OK';
    END
    ELSE
    BEGIN
        SET @fallidas = @fallidas + 1;
        PRINT 'Prueba 5: ERROR inesperado - ' + ERROR_MESSAGE();
    END;
END CATCH;

PRINT 'Fin de las pruebas de integridad P1-01.';
SELECT @correctas AS PruebasCorrectas, @fallidas AS PruebasFallidas;

-- Todo lo hecho en las pruebas se reviere
SELECT COUNT(*) AS TiposDePrueba
FROM dbo.TipoMovimiento
WHERE Id IN (900001, 900002);

SELECT COUNT(*) AS MovimientosDePrueba
FROM dbo.Movimiento
WHERE ReferenciaOrigen LIKE 'PRUEBA:P101:%';

SELECT COUNT(*) AS TotalEstados
FROM dbo.EstadoCuenta;
GO
