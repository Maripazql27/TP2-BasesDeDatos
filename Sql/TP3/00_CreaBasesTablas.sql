/* 
   TP2 - Base de Datos 1 - Cuenta de Ahorros
   Script 01: creación de la base de datos y de las tablas
*/

IF DB_ID(N'CuentaAhorrosTP2') IS NULL
    CREATE DATABASE CuentaAhorrosTP2;
GO
USE CuentaAhorrosTP2;
GO
SET NOCOUNT ON;
GO

--CATALOGOS (Id viene del XML, no es identity)
----------------------------------------------------------------------------
CREATE TABLE dbo.TipoDocuIdentidad (
    Id      INT         NOT NULL,
    Nombre  VARCHAR(64) NOT NULL,
    CONSTRAINT PK_TipoDocuIdentidad        PRIMARY KEY (Id),
    CONSTRAINT UQ_TipoDocuIdentidad_Nombre UNIQUE (Nombre)
);

CREATE TABLE dbo.TipoMoneda (
    Id      INT          NOT NULL,
    Nombre  VARCHAR(32)  NOT NULL,
    Simbolo NVARCHAR(4)  NOT NULL,
    CONSTRAINT PK_TipoMoneda        PRIMARY KEY (Id),
    CONSTRAINT UQ_TipoMoneda_Nombre UNIQUE (Nombre)
);

CREATE TABLE dbo.Parentezco (
    Id      INT         NOT NULL,
    Nombre  VARCHAR(32) NOT NULL,           
    CONSTRAINT PK_Parentezco        PRIMARY KEY (Id),
    CONSTRAINT UQ_Parentezco_Nombre UNIQUE (Nombre)
);

CREATE TABLE dbo.TipoCuentaAhorro (
    Id                      INT           NOT NULL,
    Nombre                  VARCHAR(64)   NOT NULL,
    IdTipoMoneda            INT           NOT NULL,
    SaldoMinimo             DECIMAL(18,2) NOT NULL,
    MultaSaldoMin           DECIMAL(18,2) NOT NULL,
    CargoAnual              DECIMAL(18,2) NOT NULL,   
    NumRetirosHumano        INT           NOT NULL,
    NumRetirosAutomatico    INT           NOT NULL,
    ComisionHumano          DECIMAL(18,2) NOT NULL,
    ComisionAutomatico      DECIMAL(18,2) NOT NULL,
    Interes                 DECIMAL(5,2)  NOT NULL,   
    SinpeMontoMaxDiarioSinComision DECIMAL(18,2) NULL,
    SinpeComisionExceso            DECIMAL(18,2) NULL,
    CONSTRAINT PK_TipoCuentaAhorro        PRIMARY KEY (Id),
    CONSTRAINT UQ_TipoCuentaAhorro_Nombre UNIQUE (Nombre),
    CONSTRAINT FK_TipoCuentaAhorro_Moneda FOREIGN KEY (IdTipoMoneda) REFERENCES dbo.TipoMoneda (Id),
    CONSTRAINT CK_TipoCuentaAhorro_Montos CHECK (
        SaldoMinimo >= 0 AND MultaSaldoMin >= 0 AND CargoAnual >= 0
        AND ComisionHumano >= 0 AND ComisionAutomatico >= 0
        AND NumRetirosHumano >= 0 AND NumRetirosAutomatico >= 0
        AND Interes >= 0
        AND (SinpeMontoMaxDiarioSinComision IS NULL OR SinpeMontoMaxDiarioSinComision >= 0)
        AND (SinpeComisionExceso IS NULL OR SinpeComisionExceso >= 0))
);

CREATE TABLE dbo.TipoOperacionBitacora (
    Id      INT          NOT NULL,
    Nombre  VARCHAR(64)  NOT NULL,
    CONSTRAINT PK_TipoOperacionBitacora        PRIMARY KEY (Id),
    CONSTRAINT UQ_TipoOperacionBitacora_Nombre UNIQUE (Nombre)
);
GO

 
--NO CATÁLOGOS (Id IDENTITY)
 --------------------------------------------------------------------------

CREATE TABLE dbo.Persona (
    Id                       INT IDENTITY(1,1) NOT NULL,
    IdTipoDocuIdentidad      INT           NOT NULL,
    ValorDocumentoIdentidad  VARCHAR(32)   NOT NULL,   -- llave alterna
    Nombre                   VARCHAR(64)   NOT NULL,
    FechaNacimiento          DATE          NOT NULL,
    Email                    VARCHAR(128)  NOT NULL,
    CONSTRAINT PK_Persona           PRIMARY KEY (Id),
    CONSTRAINT UQ_Persona_ValorDoc  UNIQUE (ValorDocumentoIdentidad),
    CONSTRAINT FK_Persona_TipoDocu  FOREIGN KEY (IdTipoDocuIdentidad) REFERENCES dbo.TipoDocuIdentidad (Id),
    CONSTRAINT CK_Persona_ValorDoc  CHECK (LEN(ValorDocumentoIdentidad) > 0 AND ValorDocumentoIdentidad NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_Persona_Nombre    CHECK (LEN(LTRIM(RTRIM(Nombre))) > 0),
    CONSTRAINT CK_Persona_Email     CHECK (Email LIKE '%_@_%._%')
);


CREATE TABLE dbo.Telefono (
    Id           INT IDENTITY(1,1) NOT NULL,
    IdPersona    INT         NOT NULL,
    Numero       VARCHAR(16) NOT NULL,
    CONSTRAINT PK_Telefono         PRIMARY KEY (Id),
    CONSTRAINT FK_Telefono_Persona FOREIGN KEY (IdPersona) REFERENCES dbo.Persona (Id),
    CONSTRAINT CK_Telefono_Numero  CHECK (LEN(Numero) > 0 AND Numero NOT LIKE '%[^0-9]%')
);

CREATE TABLE dbo.Cuenta (
    Id                  INT IDENTITY(1,1) NOT NULL,
    NumeroCuenta        VARCHAR(16)   NOT NULL,        
    IdPersona           INT           NOT NULL,        
    IdTipoCuentaAhorro  INT           NOT NULL,
    FechaCreacion       DATE          NOT NULL,        
    Saldo               DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_Cuenta          PRIMARY KEY (Id),
    CONSTRAINT UQ_Cuenta_Numero   UNIQUE (NumeroCuenta),
    CONSTRAINT FK_Cuenta_Persona  FOREIGN KEY (IdPersona)          REFERENCES dbo.Persona (Id),
    CONSTRAINT FK_Cuenta_Tipo     FOREIGN KEY (IdTipoCuentaAhorro) REFERENCES dbo.TipoCuentaAhorro (Id),
    CONSTRAINT CK_Cuenta_Numero   CHECK (LEN(NumeroCuenta) > 0 AND NumeroCuenta NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_Cuenta_Saldo    CHECK (Saldo >= 0)
);

CREATE TABLE dbo.Beneficiario (
    Id                  INT IDENTITY(1,1) NOT NULL,
    IdCuenta            INT          NOT NULL,
    IdPersona           INT          NOT NULL,
    IdParentezco        INT          NOT NULL,
    Porcentaje          INT          NOT NULL,
    FlagActivo          BIT          NOT NULL CONSTRAINT DF_Beneficiario_Activo DEFAULT (1),
    FechaDesactivacion  DATE         NULL,
    CONSTRAINT PK_Beneficiario            PRIMARY KEY (Id),
    CONSTRAINT FK_Beneficiario_Cuenta     FOREIGN KEY (IdCuenta)    REFERENCES dbo.Cuenta (Id),
    CONSTRAINT FK_Beneficiario_Persona    FOREIGN KEY (IdPersona)   REFERENCES dbo.Persona (Id),
    CONSTRAINT FK_Beneficiario_Parentezco FOREIGN KEY (IdParentezco) REFERENCES dbo.Parentezco (Id),
    CONSTRAINT CK_Beneficiario_Porcentaje CHECK (Porcentaje BETWEEN 0 AND 100),
    CONSTRAINT CK_Beneficiario_Activo     CHECK ((FlagActivo = 1 AND FechaDesactivacion IS NULL)
                                              OR (FlagActivo = 0 AND FechaDesactivacion IS NOT NULL))
);


CREATE TABLE dbo.EstadoCuenta (
    Id                   INT IDENTITY(1,1) NOT NULL,
    IdCuenta             INT           NOT NULL,
    FechaInicio          DATE          NOT NULL,
    FechaFin             DATE          NOT NULL,
    SaldoInicial         DECIMAL(18,2) NOT NULL,
    SaldoMinimo          DECIMAL(18,2) NOT NULL,
    SaldoFinal           DECIMAL(18,2) NOT NULL,
    InteresesAcumulados  DECIMAL(18,2) NOT NULL,
    CantRetiros          INT           NOT NULL,
    CantDepositos        INT           NOT NULL,
    CantSinpeEntrantes   INT           NOT NULL,
    CantSinpeSalientes   INT           NOT NULL,
    CONSTRAINT PK_EstadoCuenta         PRIMARY KEY (Id),
    CONSTRAINT FK_EstadoCuenta_Cuenta  FOREIGN KEY (IdCuenta) REFERENCES dbo.Cuenta (Id),
    CONSTRAINT UQ_EstadoCuenta_Periodo UNIQUE (IdCuenta, FechaInicio),
    CONSTRAINT CK_EstadoCuenta_Fechas  CHECK (FechaFin >= FechaInicio),
    CONSTRAINT CK_EstadoCuenta_Saldos  CHECK (SaldoInicial >= 0 AND SaldoMinimo >= 0 AND SaldoFinal >= 0
                                              AND InteresesAcumulados >= 0),
    CONSTRAINT CK_EstadoCuenta_Cantid  CHECK (CantRetiros >= 0 AND CantDepositos >= 0
                                              AND CantSinpeEntrantes >= 0 AND CantSinpeSalientes >= 0)
);


CREATE TABLE dbo.Usuario (
    Id              INT IDENTITY(1,1) NOT NULL,
    NombreUsuario   VARCHAR(64)  NOT NULL,        
    Clave VARCHAR(128) NOT NULL,       
    EsAdministrador BIT          NOT NULL CONSTRAINT DF_Usuario_Admin DEFAULT (0),
    IdPersona       INT          NOT NULL,
    CONSTRAINT PK_Usuario         PRIMARY KEY (Id),
    CONSTRAINT UQ_Usuario_Nombre  UNIQUE (NombreUsuario),
    CONSTRAINT FK_Usuario_Persona FOREIGN KEY (IdPersona) REFERENCES dbo.Persona (Id),
    CONSTRAINT CK_Usuario_Nombre  CHECK (LEN(LTRIM(RTRIM(NombreUsuario))) > 0)
);


CREATE TABLE dbo.UsuarioPuedeVer (
    Id          INT IDENTITY(1,1) NOT NULL,
    IdUsuario   INT NOT NULL,
    IdCuenta    INT NOT NULL,
    CONSTRAINT PK_UsuarioPuedeVer         PRIMARY KEY (Id),
    CONSTRAINT UQ_UsuarioPuedeVer         UNIQUE (IdUsuario, IdCuenta),
    CONSTRAINT FK_UsuarioPuedeVer_Usuario FOREIGN KEY (IdUsuario) REFERENCES dbo.Usuario (Id),
    CONSTRAINT FK_UsuarioPuedeVer_Cuenta  FOREIGN KEY (IdCuenta)  REFERENCES dbo.Cuenta (Id)
);


CREATE TABLE dbo.Bitacora (
    Id                INT IDENTITY(1,1) NOT NULL,
    IdUsuario         INT           NOT NULL,
    IdTipoOperacion   INT           NOT NULL,
    IP                VARCHAR(45)   NULL,            
    FechaHora         DATETIME2(3)  NOT NULL CONSTRAINT DF_Bitacora_Fecha DEFAULT (SYSDATETIME()),
    JsonAntes         NVARCHAR(MAX) NULL,            
    JsonDespues       NVARCHAR(MAX) NULL,            
    CONSTRAINT PK_Bitacora           PRIMARY KEY (Id),
    CONSTRAINT FK_Bitacora_Usuario   FOREIGN KEY (IdUsuario)       REFERENCES dbo.Usuario (Id),
    CONSTRAINT FK_Bitacora_TipoOper  FOREIGN KEY (IdTipoOperacion) REFERENCES dbo.TipoOperacionBitacora (Id)
);
GO

PRINT 'Tablas creadas: 13';
GO
