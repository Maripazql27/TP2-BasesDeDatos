SELECT (SELECT COUNT(*) FROM dbo.Persona) AS Personas,
       (SELECT COUNT(*) FROM dbo.Cuenta)  AS Cuentas,
       (SELECT COUNT(*) FROM dbo.ErrorBD) AS FilasErrorBD;

--Para comprobar que esta todo listo para correr la simulacion
       SELECT name FROM sys.procedures
WHERE name IN ('sp_CargarAltasDia','sp_AplicarMovimiento','sp_CerrarYAbrirEstadoCuenta')
ORDER BY name;   -- deben salir las 3

SELECT name FROM sys.triggers WHERE name = 'tr_Cuenta_AperturaEstadoCuenta';  -- debe salir 1

SELECT (SELECT COUNT(*) FROM dbo.Persona) AS Personas,
       (SELECT COUNT(*) FROM dbo.Cuenta)  AS Cuentas,
       (SELECT COUNT(*) FROM dbo.TipoMovimiento) AS TiposMov;   -- 0, 0 y 18