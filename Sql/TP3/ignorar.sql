SELECT (SELECT COUNT(*) FROM dbo.Persona) AS Personas,
       (SELECT COUNT(*) FROM dbo.Cuenta)  AS Cuentas,
       (SELECT COUNT(*) FROM dbo.ErrorBD) AS FilasErrorBD;