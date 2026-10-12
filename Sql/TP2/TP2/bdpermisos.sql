USE CuentaAhorrosTP2;
GO

/* ---- Parte 1: tabla dbo.ErrorBD (la usa sp_RegistrarError). Solo si no existe. */
IF OBJECT_ID(N'dbo.ErrorBD', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ErrorBD (
        Id              INT IDENTITY(1,1) NOT NULL,
        FechaHora       DATETIME2(3)   NOT NULL CONSTRAINT DF_ErrorBD_Fecha DEFAULT (SYSDATETIME()),
        NumeroError     INT            NULL,
        Severidad       INT            NULL,
        Estado          INT            NULL,
        Procedimiento   NVARCHAR(128)  NULL,
        Linea           INT            NULL,
        Mensaje         NVARCHAR(4000) NOT NULL,
        CONSTRAINT PK_ErrorBD PRIMARY KEY (Id)
    );
END;
GO

 ---- Parte 2: permisos de app_tp2 (el usuario con el que se conecta Node).
 
GRANT EXECUTE ON dbo.sp_IniciarSesion          TO app_tp2;
GRANT EXECUTE ON dbo.sp_CerrarSesion           TO app_tp2;
GRANT EXECUTE ON dbo.sp_ListarCuentasUsuario   TO app_tp2;
GRANT EXECUTE ON dbo.sp_ConsultarEstadosCuenta TO app_tp2;
GRANT EXECUTE ON dbo.sp_ListarParentezcos      TO app_tp2;
GRANT EXECUTE ON dbo.sp_ListarTiposDocumento   TO app_tp2;
GRANT EXECUTE ON dbo.sp_ListarBeneficiarios    TO app_tp2;
GRANT EXECUTE ON dbo.sp_AgregarBeneficiario    TO app_tp2;
GRANT EXECUTE ON dbo.sp_ActualizarBeneficiario TO app_tp2;
GRANT EXECUTE ON dbo.sp_EliminarBeneficiario   TO app_tp2;
GO