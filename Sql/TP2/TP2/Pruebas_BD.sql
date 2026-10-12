
USE CuentaAhorrosTP2;
GO

-- TP2: Pruebas de base de datos
-- 1. Verificar cantidad de registros cargados.

SELECT 'Persona' AS Tabla, COUNT(*) AS Cantidad
FROM dbo.Persona
UNION ALL
SELECT 'Telefono', COUNT(*) FROM dbo.Telefono
UNION ALL
SELECT 'Cuenta', COUNT(*) FROM dbo.Cuenta
UNION ALL
SELECT 'Beneficiario', COUNT(*) FROM dbo.Beneficiario
UNION ALL
SELECT 'EstadoCuenta', COUNT(*) FROM dbo.EstadoCuenta
UNION ALL
SELECT 'Usuario', COUNT(*) FROM dbo.Usuario
UNION ALL
SELECT 'UsuarioPuedeVer', COUNT(*) FROM dbo.UsuarioPuedeVer;



-- 2. Verificar que cada persona tenga al menos dos telefonos.
-- Resultado esperado: ninguna fila.

SELECT
    P.Id,
    P.Nombre,
    COUNT(T.Id) AS CantidadTelefonos
FROM dbo.Persona P
LEFT JOIN dbo.Telefono T
    ON P.Id = T.IdPersona
GROUP BY P.Id, P.Nombre
HAVING COUNT(T.Id) < 2;


-- 3. Verificar beneficiarios y porcentajes iniciales.
-- Resultado esperado: ninguna fila.

SELECT
    C.NumeroCuenta,
    COUNT(B.Id) AS BeneficiariosActivos,
    COALESCE(SUM(B.Porcentaje), 0) AS SumaPorcentajes
FROM dbo.Cuenta C
LEFT JOIN dbo.Beneficiario B
    ON C.Id = B.IdCuenta
    AND B.FlagActivo = 1
GROUP BY C.Id, C.NumeroCuenta
HAVING COUNT(B.Id) > 3
    OR COALESCE(SUM(B.Porcentaje), 0) <> 100;


    -- 4. Verificar los registros cargados en los catalogos.

SELECT 'TipoDocuIdentidad' AS Tabla, COUNT(*) AS Cantidad
FROM dbo.TipoDocuIdentidad
UNION ALL
SELECT 'TipoMoneda', COUNT(*) FROM dbo.TipoMoneda
UNION ALL
SELECT 'Parentezco', COUNT(*) FROM dbo.Parentezco
UNION ALL
SELECT 'TipoCuentaAhorro', COUNT(*) FROM dbo.TipoCuentaAhorro
UNION ALL
SELECT 'TipoOperacionBitacora', COUNT(*) FROM dbo.TipoOperacionBitacora;