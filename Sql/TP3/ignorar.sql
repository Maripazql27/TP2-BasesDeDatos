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




/*
 Limpieza de datos de la simulacion.
   Borra TODOS los datos de cuentas y movimientos para poder volver a correr
   Simulacion_TP3.sql. NO toca los catalogos (TipoMoneda, TipoCuentaAhorro,
   TipoMovimiento, etc.) ni los SP, ni el trigger.
   Tambien deja vacia dbo.ErrorBD y reinicia los Id para que empiecen en 1.
   El orden de los DELETE respeta las llaves foraneas (primero las tablas hijas).
*/
USE CuentaAhorrosTP2;
GO

DELETE FROM dbo.Bitacora;
DELETE FROM dbo.UsuarioPuedeVer;
DELETE FROM dbo.Usuario;
DELETE FROM dbo.Movimiento;
DELETE FROM dbo.EstadoCuenta;
DELETE FROM dbo.Beneficiario;
DELETE FROM dbo.Cuenta;
DELETE FROM dbo.Telefono;
DELETE FROM dbo.Persona;
DELETE FROM dbo.ErrorBD;

DBCC CHECKIDENT ('dbo.Bitacora',        RESEED, 0);
DBCC CHECKIDENT ('dbo.UsuarioPuedeVer', RESEED, 0);
DBCC CHECKIDENT ('dbo.Usuario',         RESEED, 0);
DBCC CHECKIDENT ('dbo.Movimiento',      RESEED, 0);
DBCC CHECKIDENT ('dbo.EstadoCuenta',    RESEED, 0);
DBCC CHECKIDENT ('dbo.Beneficiario',    RESEED, 0);
DBCC CHECKIDENT ('dbo.Cuenta',          RESEED, 0);
DBCC CHECKIDENT ('dbo.Telefono',        RESEED, 0);
DBCC CHECKIDENT ('dbo.Persona',         RESEED, 0);
DBCC CHECKIDENT ('dbo.ErrorBD',         RESEED, 0);
GO

-- Verificacion: todo en 0, y los catalogos intactos (TipoMovimiento = 18)
SELECT (SELECT COUNT(*) FROM dbo.Persona)        AS Personas,
       (SELECT COUNT(*) FROM dbo.Cuenta)         AS Cuentas,
       (SELECT COUNT(*) FROM dbo.EstadoCuenta)   AS Estados,
       (SELECT COUNT(*) FROM dbo.Movimiento)     AS Movimientos,
       (SELECT COUNT(*) FROM dbo.ErrorBD)        AS Errores,
       (SELECT COUNT(*) FROM dbo.TipoMovimiento) AS TiposMov_esperado_18;
GO




USE CuentaAhorrosTP2;

SELECT E.Nombre AS SP_Que_Falta, E.Usado_Por
FROM (
    SELECT 'sp_CargarCatalogos' AS Nombre, 'Carga de catalogos' AS Usado_Por
    UNION ALL SELECT 'sp_CargarAltasDia',                    'Simulacion'
    UNION ALL SELECT 'sp_AplicarMovimiento',                 'Simulacion'
    UNION ALL SELECT 'sp_CerrarYAbrirEstadoCuenta',          'Simulacion'
    UNION ALL SELECT 'sp_RegistrarBitacora',                 'Web y SP de consulta'
    UNION ALL SELECT 'sp_RegistrarError',                    'Web y SP de consulta'
    UNION ALL SELECT 'sp_IniciarSesion',                     'Web: login'
    UNION ALL SELECT 'sp_CerrarSesion',                      'Web: logout'
    UNION ALL SELECT 'sp_ListarCuentasUsuario',              'Web: mis cuentas'
    UNION ALL SELECT 'sp_ConsultarEstadosCuenta',            'Web: estados'
    UNION ALL SELECT 'sp_ConsultarMovimientosEstadoCuenta',  'Web: movimientos'
    UNION ALL SELECT 'sp_ListarParentezcos',                 'Web: beneficiarios'
    UNION ALL SELECT 'sp_ListarTiposDocumento',              'Web: beneficiarios'
    UNION ALL SELECT 'sp_ListarBeneficiarios',               'Web: beneficiarios'
    UNION ALL SELECT 'sp_AgregarBeneficiario',               'Web: beneficiarios'
    UNION ALL SELECT 'sp_ActualizarBeneficiario',            'Web: beneficiarios'
    UNION ALL SELECT 'sp_EliminarBeneficiario',              'Web: beneficiarios'
) AS E
LEFT JOIN sys.procedures AS P
    ON P.name = E.Nombre
WHERE P.name IS NULL;

-- Y el trigger de apertura de estado:
SELECT 'tr_Cuenta_AperturaEstadoCuenta' AS Trigger_Que_Falta
WHERE NOT EXISTS (SELECT 1 FROM sys.triggers WHERE name = 'tr_Cuenta_AperturaEstadoCuenta');