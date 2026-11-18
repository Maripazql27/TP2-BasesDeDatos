/*
   Prueba de sp_CargarAltasDia con el dia 2026-03-01 del XML real.
   Esperado en la prueba 1: Persona 5, Telefono 10, Cuenta 2, EstadoCuenta 2,
   Beneficiario 2, Usuario 2, UsuarioPuedeVer 2. Todo termina en ROLLBACK.
   Requiere: catalogos cargados y dbo.ErrorBD creada.
*/
USE CuentaAhorrosTP2;
GO
DECLARE @x XML = N'<Operaciones>
  <FechaOperacion Fecha="2026-03-01">
    <Persona TipoDocuIdentidad="1" Nombre="Ana Lucía Mora Jiménez" ValorDocumentoIdentidad="117250431" FechaNacimiento="1992-04-17" Email="ana.mora@ejemplo.com" telefono1="88123456" telefono2="22541234"/>
    <Persona TipoDocuIdentidad="1" Nombre="Carlos Andrés Vargas Solís" ValorDocumentoIdentidad="205430876" FechaNacimiento="1985-11-02" Email="carlos.vargas@ejemplo.com" telefono1="87214598" telefono2="24456712"/>
    <Persona TipoDocuIdentidad="1" Nombre="Rosa Jiménez Arias" ValorDocumentoIdentidad="109870345" FechaNacimiento="1960-02-11" Email="rosa.jimenez@ejemplo.com" telefono1="83321907" telefono2="22549087"/>
    <Persona TipoDocuIdentidad="1" Nombre="Mateo Mora Jiménez" ValorDocumentoIdentidad="118900456" FechaNacimiento="2004-08-05" Email="mateo.mora@ejemplo.com" telefono1="86457732" telefono2="22541234"/>
    <Persona TipoDocuIdentidad="1" Nombre="Elena Vargas Solís" ValorDocumentoIdentidad="206540321" FechaNacimiento="1989-05-22" Email="elena.vargas@ejemplo.com" telefono1="88904561" telefono2="24456712"/>
    <Cuenta ValorDocumentoIdentidadDelCliente="117250431" TipoCuentaId="1" NumeroCuenta="11000001" FechaCreacion="2026-03-01" Saldo="0.00"/>
    <Cuenta ValorDocumentoIdentidadDelCliente="205430876" TipoCuentaId="2" NumeroCuenta="11000002" FechaCreacion="2026-03-01" Saldo="0.00"/>
    <Beneficiario NumeroCuenta="11000001" ValorDocumentoIdentidadBeneficiario="109870345" IdParentezco="2" Porcentaje="60"/>
    <Beneficiario NumeroCuenta="11000001" ValorDocumentoIdentidadBeneficiario="118900456" IdParentezco="5" Porcentaje="40"/>
    <Usuario User="amora" Pass="AnaMora2026*" EsAdministrador="0" ValorDocId="117250431"/>
    <Usuario User="cvargas" Pass="Carlos2026*" EsAdministrador="0" ValorDocId="205430876"/>
    <UsuarioPuedeVer User="amora" NumeroCuenta="11000001"/>
    <UsuarioPuedeVer User="cvargas" NumeroCuenta="11000002"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000001" Monto="250000.00" Descripcion="Depósito de apertura sucursal San Pedro"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000002" Monto="500000.00" Descripcion="Depósito de apertura sucursal Heredia"/>
  </FechaOperacion>
</Operaciones>';
DECLARE @r INT;
DECLARE @errAntes INT = (SELECT COUNT(*) FROM dbo.ErrorBD);

-- carga normal del dia (esperado codigo 0)
BEGIN TRANSACTION;
EXEC dbo.sp_CargarAltasDia @inXml = @x, @inFecha = '2026-03-01', @outResultCode = @r OUTPUT;
SELECT @r AS Codigo_Prueba1;
SELECT (SELECT COUNT(*) FROM dbo.Persona) AS Personas,
       (SELECT COUNT(*) FROM dbo.Telefono) AS Telefonos,
       (SELECT COUNT(*) FROM dbo.Cuenta) AS Cuentas,
       (SELECT COUNT(*) FROM dbo.EstadoCuenta) AS Estados,
       (SELECT COUNT(*) FROM dbo.Beneficiario) AS Beneficiarios,
       (SELECT COUNT(*) FROM dbo.Usuario) AS Usuarios,
       (SELECT COUNT(*) FROM dbo.UsuarioPuedeVer) AS PuedeVer;
SELECT C.NumeroCuenta, E.FechaInicio, E.FechaFin, E.SaldoInicial
FROM dbo.EstadoCuenta E INNER JOIN dbo.Cuenta C ON C.Id = E.IdCuenta;
ROLLBACK TRANSACTION;

-- fecha sin nodo FechaOperacion en este XML: codigo 0 y sin cambios
EXEC dbo.sp_CargarAltasDia @inXml = @x, @inFecha = '2026-03-10', @outResultCode = @r OUTPUT;
SELECT @r AS Codigo_Prueba2_DiaSinNodo;

-- XML nulo (esperado 50400) y fecha nula (esperado 50401)
EXEC dbo.sp_CargarAltasDia @inXml = NULL, @inFecha = '2026-03-01', @outResultCode = @r OUTPUT;
SELECT @r AS Codigo_Prueba3a;
EXEC dbo.sp_CargarAltasDia @inXml = @x, @inFecha = NULL, @outResultCode = @r OUTPUT;
SELECT @r AS Codigo_Prueba3b;

-- cargar dos veces el mismo dia -> la segunda falla (50000),
-- se deshace TODO y queda una fila nueva en ErrorBD
BEGIN TRANSACTION;
EXEC dbo.sp_CargarAltasDia @inXml = @x, @inFecha = '2026-03-01', @outResultCode = @r OUTPUT;
EXEC dbo.sp_CargarAltasDia @inXml = @x, @inFecha = '2026-03-01', @outResultCode = @r OUTPUT;
SELECT @r AS Codigo_Prueba4;
IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION;
SELECT (SELECT COUNT(*) FROM dbo.Persona) AS PersonasQuedan_esperado_0,
       (SELECT COUNT(*) FROM dbo.ErrorBD) - @errAntes AS FilasNuevasErrorBD_esperado_1;
SELECT TOP (1) NumeroError, Procedimiento, Mensaje FROM dbo.ErrorBD ORDER BY Id DESC;