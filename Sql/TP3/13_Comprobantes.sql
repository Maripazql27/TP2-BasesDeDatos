/*

   Enunciado, seccion Dos: los movimientos de compras, retiros o depositos
   generan un comprobante que llega al correo del dueno de la cuenta, y la
   configuracion del tipo de movimiento indica si genera comprobante o no
   (TipoMovimiento.flagGeneraComprobante).

   Diseno, como en la clase 18 (14 oct):
     - El comprobante guarda el texto del correo y se inserta PRIMERO, en la
       misma transaccion que el movimiento (sp_AplicarMovimiento). Es el
       objeto menos importante: comprobante, despues movimiento y al final
       el saldo.
     - La vinculacion comprobante-movimiento es 1 a 1 y el FK queda en
       Movimiento (IdComprobante), porque el comprobante se inserta antes.
     - El correo NO se envia dentro de la transaccion (un correo no se puede
       deshacer). Lo envia despues el servidor web, desde la pagina
       "Control de la simulacion" (solo administrador), y cada comprobante
       queda marcado como enviado con sp_RegistrarEnvioComprobante.

   Crea:
     dbo.Comprobante               una fila por comprobante: a quien va, el
                                   asunto, el texto del correo y el estado
                                   del envio
     dbo.Movimiento.IdComprobante  FK al comprobante; NULL en los tipos de
                                   movimiento que no generan comprobante
     dbo.fnTextoMonto              un monto como texto para el correo, con
                                   el mismo formato de la pagina web

   Se puede correr varias veces: lo que ya existe no se toca.
   Orden de instalacion: despues de 12_ControlSimulacion.sql y antes de
   Sp_AplicarMovimiento.sql.
*/
USE CuentaAhorrosTP2;
GO

IF OBJECT_ID('dbo.Comprobante', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Comprobante (
        Id                INT            IDENTITY(1,1) NOT NULL,
        IdCuenta          INT            NOT NULL,  -- cuenta del movimiento
        FechaOperacion    DATE           NOT NULL,  -- fecha del movimiento
        EmailDestino      VARCHAR(128)   NOT NULL,  -- correo del dueno
        Asunto            NVARCHAR(128)  NOT NULL,
        TextoEmail        NVARCHAR(2000) NOT NULL,
        FlagEnviado       BIT            NOT NULL
            CONSTRAINT DF_Comprobante_Enviado DEFAULT (0),
        CantIntentosEnvio INT            NOT NULL
            CONSTRAINT DF_Comprobante_Intentos DEFAULT (0),
        UltimoErrorEnvio  NVARCHAR(400)  NULL,      -- del ultimo intento fallido
        FechaHoraCreacion DATETIME2(0)   NOT NULL
            CONSTRAINT DF_Comprobante_Creacion DEFAULT (SYSDATETIME()),
        FechaHoraEnvio    DATETIME2(0)   NULL,
        CONSTRAINT PK_Comprobante PRIMARY KEY (Id),
        CONSTRAINT FK_Comprobante_Cuenta
            FOREIGN KEY (IdCuenta) REFERENCES dbo.Cuenta (Id),
        CONSTRAINT CK_Comprobante_Email
            CHECK (EmailDestino LIKE '%_@_%._%'),
        CONSTRAINT CK_Comprobante_Intentos
            CHECK (CantIntentosEnvio >= 0)
    );
END;
GO

-- FK en Movimiento. Queda en NULL en comisiones, intereses, multas y
-- cargos, que no generan comprobante (flagGeneraComprobante = 0).
IF NOT EXISTS (SELECT 1
               FROM sys.columns AS SC
               WHERE SC.object_id = OBJECT_ID('dbo.Movimiento')
                 AND SC.name = 'IdComprobante')
BEGIN
    ALTER TABLE dbo.Movimiento
        ADD IdComprobante INT NULL;
END;
GO

IF NOT EXISTS (SELECT 1
               FROM sys.foreign_keys AS FK
               WHERE FK.name = 'FK_Movimiento_Comprobante')
BEGIN
    ALTER TABLE dbo.Movimiento
        ADD CONSTRAINT FK_Movimiento_Comprobante
        FOREIGN KEY (IdComprobante) REFERENCES dbo.Comprobante (Id);
END;
GO

/*
   dbo.fnTextoMonto: un monto como texto para el correo, con el formato de
   la pagina web: espacio para los miles, coma decimal y el signo antes del
   simbolo de la moneda.
     SELECT dbo.fnTextoMonto(-45000.00, N'$');   -- -$ 45 000,00
     SELECT dbo.fnTextoMonto(594249.01, NULL);   -- 594 249,01
   CONVERT de MONEY con estilo 1 da '45,000.00'; despues las comas pasan a
   espacios y el punto a coma.
*/
CREATE OR ALTER FUNCTION dbo.fnTextoMonto (
    @inMonto   DECIMAL(18,2),
    @inSimbolo NVARCHAR(4)
)
RETURNS NVARCHAR(40)
AS
BEGIN
    DECLARE @textoNumero NVARCHAR(40);
    DECLARE @textoSigno  NVARCHAR(1) = N'';

    SET @textoNumero = CONVERT(NVARCHAR(40), CONVERT(MONEY, ABS(@inMonto)), 1);
    SET @textoNumero = REPLACE(@textoNumero, N',', N' ');
    SET @textoNumero = REPLACE(@textoNumero, N'.', N',');

    IF (@inMonto < 0)
    BEGIN
        SET @textoSigno = N'-';
    END;

    RETURN @textoSigno + ISNULL(@inSimbolo + N' ', N'') + @textoNumero;
END;
GO

-- Verificacion: las tres primeras columnas en 1, y los ejemplos deben salir
-- '-$ 45 000,00' y '594 249,01'
SELECT
    (SELECT COUNT(*)
     FROM sys.tables AS T
     WHERE T.name = 'Comprobante')                 AS TablaComprobante,
    (SELECT COUNT(*)
     FROM sys.columns AS SC
     WHERE SC.object_id = OBJECT_ID('dbo.Movimiento')
       AND SC.name = 'IdComprobante')              AS ColumnaEnMovimiento,
    (SELECT COUNT(*)
     FROM sys.foreign_keys AS FK
     WHERE FK.name = 'FK_Movimiento_Comprobante')  AS LlaveForanea,
    dbo.fnTextoMonto(-45000.00, N'$')              AS EjemploNegativo,
    dbo.fnTextoMonto(594249.01, NULL)              AS EjemploPositivo;
GO
