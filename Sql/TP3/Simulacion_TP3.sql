/*
   Recorre TODAS las fechas del XML de operaciones, una por una y en orden
   ascendente (aunque la fecha no tenga nodo FechaOperacion). Por cada dia:
      1. Altas:       EXEC dbo.sp_CargarAltasDia
                      (Persona -> Cuenta -> Beneficiario -> Usuario -> PuedeVer)
      2. Movimientos: uno por uno, en el orden del XML, con
                      EXEC dbo.sp_AplicarMovimiento
      3. Cierres:     cuentas cuyo estado vence ese dia, en orden de Id (PK),
                      con EXEC dbo.sp_CerrarYAbrirEstadoCuenta

   Control, con dbo.CorridaSimulacion y
   dbo.ControlSimulacion (12_ControlSimulacion.sql):
     - No se corre mas de una vez: una fecha terminada no se vuelve a
       procesar. Si todas estan terminadas, el script no hace nada.
     - No se brinca una fecha: empieza siempre por la fecha pendiente mas
       antigua, y antes de procesar una fecha revisa que la anterior este
       terminada.
     - Si falla sin terminar, la siguiente corrida reanuda esa fecha desde lo
       ultimo procesado: no repite las altas, sigue con el movimiento que
       sigue al ultimo procesado, y con la cuenta (PK) que sigue a la ultima
       cerrada.

   Si falla un alta o un cierre, la corrida SE DETIENE en esa fecha y deja el
   error en dbo.ErrorBD; se corrige la causa y se vuelve a correr (reanuda).
   Si un movimiento es rechazado (fondos insuficientes, etc.) se registra en
   dbo.ErrorBD y la simulacion continua con el siguiente.
*/
USE CuentaAhorrosTP2;
GO
SET NOCOUNT ON;

-- Constantes
DECLARE @true  BIT = 1;
DECLARE @false BIT = 0;
DECLARE @resultadoCompleta      INT = 0;
DECLARE @resultadoSinPendientes INT = 1;
DECLARE @resultadoError         INT = 2;
DECLARE @resultadoPrueba        INT = 3;
DECLARE @codigoMovYaRegistrado  INT = 50203;  -- de sp_AplicarMovimiento
DECLARE @codigoPeriodoCerrado   INT = 50303;  -- de sp_CerrarYAbrirEstadoCuenta

-- SOLO PARA LA PRUEBA DE REANUDACION (Pruebas_ReanudacionSimulacion.sql):
-- detienen la corrida a proposito, como si fallara. En una corrida normal
-- las tres quedan en NULL.
DECLARE @pruebaFechaDetener           DATE = Null;  -- ej. '2026-04-01'
DECLARE @pruebaDetenerTrasMovimientos INT  = Null;  -- ej. 3
DECLARE @pruebaDetenerTrasCierres     INT  = Null;  -- ej. 1

-- XML de operaciones (el archivo OperacionesTarea3.xml del profesor)
DECLARE @xmlOperaciones XML = N'<!-- Simulación - Tercera Tarea Programada - Bases de Datos I.
     Periodo: 2026-03-01 a 2026-06-30 (4 meses), 100 movimientos.
     Las fechas sin datos se omiten; el proceso igual debe recorrer todas las fechas.
     Montos en la moneda de la cuenta. Los IDs refieren a CatalogosTarea3.xml. -->
<Operaciones>
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
  <FechaOperacion Fecha="2026-03-02">
    <Beneficiario NumeroCuenta="11000002" ValorDocumentoIdentidadBeneficiario="206540321" IdParentezco="6" Porcentaje="100"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-03">
    <Persona TipoDocuIdentidad="1" Nombre="María Fernanda Rojas Chaves" ValorDocumentoIdentidad="304560129" FechaNacimiento="1999-07-23" Email="mfernanda.rojas@ejemplo.com" telefono1="85126743" telefono2="25519087"/>
    <Persona TipoDocuIdentidad="1" Nombre="Luis Diego Castro Brenes" ValorDocumentoIdentidad="503210765" FechaNacimiento="1978-09-14" Email="luis.castro@ejemplo.com" telefono1="89017734" telefono2="26651290"/>
    <Cuenta ValorDocumentoIdentidadDelCliente="304560129" TipoCuentaId="1" NumeroCuenta="11000003" FechaCreacion="2026-03-03" Saldo="0.00"/>
    <Beneficiario NumeroCuenta="11000003" ValorDocumentoIdentidadBeneficiario="503210765" IdParentezco="7" Porcentaje="100"/>
    <Usuario User="mrojas" Pass="MaFer2026*" EsAdministrador="0" ValorDocId="304560129"/>
    <UsuarioPuedeVer User="mrojas" NumeroCuenta="11000003"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000003" Monto="150000.00" Descripcion="Depósito de apertura sucursal Cartago"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-04">
    <Movimientos Tipo="Compra" CodigoCuenta="11000001" Monto="18500.00" Descripcion="Compra Más x Menos Zapote"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-05">
    <Persona TipoDocuIdentidad="1" Nombre="José Pablo Araya Quesada" ValorDocumentoIdentidad="112340987" FechaNacimiento="2001-01-30" Email="josepablo.araya@ejemplo.com" telefono1="84569021" telefono2="22271543"/>
    <Cuenta ValorDocumentoIdentidadDelCliente="112340987" TipoCuentaId="1" NumeroCuenta="11000004" FechaCreacion="2026-03-05" Saldo="0.00"/>
    <Usuario User="jaraya" Pass="JosePa2026*" EsAdministrador="0" ValorDocId="112340987"/>
    <UsuarioPuedeVer User="jaraya" NumeroCuenta="11000004"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000004" Monto="60000.00" Descripcion="Depósito de apertura sucursal San José"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-06">
    <Movimientos Tipo="Compra" CodigoCuenta="11000002" Monto="35600.00" Descripcion="Compra AutoMercado Escazú"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-09">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="20000.00" Descripcion="Retiro ATM BCR Mall San Pedro"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-10">
    <Persona TipoDocuIdentidad="1" Nombre="Gabriela Sánchez Villalobos" ValorDocumentoIdentidad="401230456" FechaNacimiento="1983-03-29" Email="gabriela.sanchez@ejemplo.com" telefono1="88762314" telefono2="22608845"/>
    <Persona TipoDocuIdentidad="1" Nombre="Tomás Sánchez Villalobos" ValorDocumentoIdentidad="401980765" FechaNacimiento="1991-10-03" Email="tomas.sanchez@ejemplo.com" telefono1="87125590" telefono2="22608845"/>
    <Persona TipoDocuIdentidad="1" Nombre="Daniela Sánchez Villalobos" ValorDocumentoIdentidad="402150987" FechaNacimiento="1996-06-12" Email="daniela.sanchez@ejemplo.com" telefono1="86234478" telefono2="22608845"/>
    <Cuenta ValorDocumentoIdentidadDelCliente="401230456" TipoCuentaId="3" NumeroCuenta="11000005" FechaCreacion="2026-03-10" Saldo="0.00"/>
    <Cuenta ValorDocumentoIdentidadDelCliente="117250431" TipoCuentaId="4" NumeroCuenta="21000001" FechaCreacion="2026-03-10" Saldo="0.00"/>
    <Beneficiario NumeroCuenta="11000005" ValorDocumentoIdentidadBeneficiario="401980765" IdParentezco="5" Porcentaje="50"/>
    <Beneficiario NumeroCuenta="11000005" ValorDocumentoIdentidadBeneficiario="402150987" IdParentezco="6" Porcentaje="25"/>
    <Beneficiario NumeroCuenta="11000005" ValorDocumentoIdentidadBeneficiario="112340987" IdParentezco="7" Porcentaje="25"/>
    <Beneficiario NumeroCuenta="21000001" ValorDocumentoIdentidadBeneficiario="109870345" IdParentezco="2" Porcentaje="100"/>
    <Usuario User="gsanchez" Pass="Gaby2026*" EsAdministrador="0" ValorDocId="401230456"/>
    <Usuario User="tsanchez" Pass="Tomas2026*" EsAdministrador="0" ValorDocId="401980765"/>
    <UsuarioPuedeVer User="gsanchez" NumeroCuenta="11000005"/>
    <UsuarioPuedeVer User="tsanchez" NumeroCuenta="11000005"/>
    <UsuarioPuedeVer User="amora" NumeroCuenta="21000001"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000005" Monto="2500000.00" Descripcion="Depósito de apertura sucursal Central"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="21000001" Monto="1500.00" Descripcion="Depósito de apertura en dólares sucursal Central"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-12">
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000005" Monto="350000.00" Descripcion="A Distribuidora El Roble - factura 1043"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-14">
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000002" Monto="60000.00" Descripcion="A Elena Vargas - compras casa"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-15">
    <Persona TipoDocuIdentidad="2" Nombre="Isabel Castro Brenes" ValorDocumentoIdentidad="155812345678" FechaNacimiento="1980-01-27" Email="isabel.castro@ejemplo.com" telefono1="83894411" telefono2="26651290"/>
    <Cuenta ValorDocumentoIdentidadDelCliente="503210765" TipoCuentaId="2" NumeroCuenta="11000007" FechaCreacion="2026-03-15" Saldo="0.00"/>
    <Beneficiario NumeroCuenta="11000007" ValorDocumentoIdentidadBeneficiario="155812345678" IdParentezco="6" Porcentaje="100"/>
    <Usuario User="lcastro" Pass="Luis2026*" EsAdministrador="0" ValorDocId="503210765"/>
    <UsuarioPuedeVer User="lcastro" NumeroCuenta="11000007"/>
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000001" Monto="180000.00" Descripcion="Salario quincena marzo - Soluciones Tico S.A."/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000007" Monto="300000.00" Descripcion="Depósito de apertura sucursal Liberia"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-17">
    <Movimientos Tipo="Compra" CodigoCuenta="11000003" Monto="8900.00" Descripcion="Compra Pulpería La Amistad"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-18">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000005" Monto="480000.00" Descripcion="De Hotel Montaña Azul - factura 221"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-20">
    <Movimientos Tipo="Compra" CodigoCuenta="11000004" Monto="14500.00" Descripcion="Compra Soda Tapia"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-21">
    <Movimientos Tipo="Compra" CodigoCuenta="11000007" Monto="67800.00" Descripcion="Compra Ferretería El Lagar"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-22">
    <Movimientos Tipo="Compra" CodigoCuenta="11000001" Monto="12750.00" Descripcion="Compra Farmacia La Bomba"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-25">
    <Movimientos Tipo="Compra" CodigoCuenta="21000001" Monto="89.99" Descripcion="Compra Amazon.com"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-26">
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000005" Monto="120000.00" Descripcion="A Tomás Sánchez - planilla marzo"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-28">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000002" Monto="650000.00" Descripcion="Salario marzo - Constructora del Valle"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-30">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000003" Monto="210000.00" Descripcion="Pago servicios profesionales - Clínica Dental Sonrisas"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-03-31">
    <Persona TipoDocuIdentidad="1" Nombre="Valeria Alfaro Méndez" ValorDocumentoIdentidad="601870432" FechaNacimiento="1995-12-31" Email="valeria.alfaro@ejemplo.com" telefono1="86015528" telefono2="26614470"/>
    <Cuenta ValorDocumentoIdentidadDelCliente="601870432" TipoCuentaId="1" NumeroCuenta="11000008" FechaCreacion="2026-03-31" Saldo="0.00"/>
    <Beneficiario NumeroCuenta="11000008" ValorDocumentoIdentidadBeneficiario="205430876" IdParentezco="7" Porcentaje="100"/>
    <Usuario User="valfaro" Pass="Vale2026*" EsAdministrador="0" ValorDocId="601870432"/>
    <UsuarioPuedeVer User="valfaro" NumeroCuenta="11000008"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000008" Monto="80000.00" Descripcion="Depósito de apertura sucursal Puntarenas"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-02">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000004" Monto="45000.00" Descripcion="Pago medio tiempo - Call Center Zeta"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-03">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="15000.00" Descripcion="Retiro ATM Plaza del Sol"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-04">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000007" Monto="520000.00" Descripcion="Salario marzo - Hospital Enrique Baltodano"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-06">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="10000.00" Descripcion="Retiro ATM Terminal de buses Coca Cola"/>
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="11000003" Monto="30000.00" Descripcion="Retiro en ventana sucursal Cartago"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-07">
    <Movimientos Tipo="Compra" CodigoCuenta="11000008" Monto="9500.00" Descripcion="Compra Cafetería Alma de Café"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-08">
    <Movimientos Tipo="Deposito ATM" CodigoCuenta="11000001" Monto="40000.00" Descripcion="Depósito ATM BN Sabanilla"/>
    <Movimientos Tipo="Compra" CodigoCuenta="11000005" Monto="185000.00" Descripcion="Compra EPA Tibás - materiales"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-09">
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="11000003" Monto="25000.00" Descripcion="Retiro en ventana sucursal Paraíso"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-10">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="20000.00" Descripcion="Retiro ATM Mall San Pedro"/>
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000004" Monto="50000.00" Descripcion="Retiro ATM Avenida Segunda"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-11">
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="11000002" Monto="100000.00" Descripcion="Retiro en ventana sucursal Heredia"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-12">
    <Persona TipoDocuIdentidad="1" Nombre="Andrés Fallas Ulate" ValorDocumentoIdentidad="702340981" FechaNacimiento="1988-03-08" Email="andres.fallas@ejemplo.com" telefono1="85547702" telefono2="27581133"/>
    <Cuenta ValorDocumentoIdentidadDelCliente="702340981" TipoCuentaId="2" NumeroCuenta="11000009" FechaCreacion="2026-04-12" Saldo="0.00"/>
    <Beneficiario NumeroCuenta="11000009" ValorDocumentoIdentidadBeneficiario="304560129" IdParentezco="8" Porcentaje="100"/>
    <Usuario User="afallas" Pass="Andres2026*" EsAdministrador="0" ValorDocId="702340981"/>
    <UsuarioPuedeVer User="afallas" NumeroCuenta="11000009"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000009" Monto="400000.00" Descripcion="Depósito de apertura sucursal Pérez Zeledón"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-13">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="5000.00" Descripcion="Retiro ATM Universidad"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-14">
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="11000003" Monto="20000.00" Descripcion="Retiro en ventana sucursal Cartago"/>
    <Movimientos Tipo="Compra" CodigoCuenta="21000001" Monto="45.50" Descripcion="Compra Steam"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-15">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000001" Monto="180000.00" Descripcion="Salario quincena abril - Soluciones Tico S.A."/>
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="10000.00" Descripcion="Retiro ATM Plaza del Sol"/>
    <Movimientos Tipo="Compra" CodigoCuenta="11000009" Monto="54300.00" Descripcion="Compra Palí Hatillo"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-16">
    <Movimientos Tipo="Compra" CodigoCuenta="11000004" Monto="31750.00" Descripcion="Compra Pequeño Mundo Paso Ancho"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-17">
    <Movimientos Tipo="Deposito ATM" CodigoCuenta="11000001" Monto="25000.00" Descripcion="Depósito ATM BN Sabanilla"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000003" Monto="60000.00" Descripcion="Depósito en ventana sucursal Cartago"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-18">
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000007" Monto="150000.00" Descripcion="A Isabel Castro - mensualidad"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-19">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000008" Monto="120000.00" Descripcion="Pago freelance diseño gráfico"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-20">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="20000.00" Descripcion="Retiro ATM Avenida Central"/>
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000005" Monto="250000.00" Descripcion="A Transportes Ruta 32 - fletes"/>
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000005" Monto="300000.00" Descripcion="A Distribuidora El Roble - factura 1077"/>
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000005" Monto="180000.00" Descripcion="A Tomás Sánchez - planilla abril"/>
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000005" Monto="95000.00" Descripcion="A Servicios Contables JM"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-21">
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="11000003" Monto="15000.00" Descripcion="Retiro en ventana sucursal Cartago"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-23">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="15000.00" Descripcion="Retiro ATM Mall San Pedro"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-24">
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="11000003" Monto="20000.00" Descripcion="Retiro en ventana sucursal Paraíso"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-25">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="10000.00" Descripcion="Retiro ATM Terminal de buses Coca Cola"/>
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000004" Monto="70000.00" Descripcion="Pago medio tiempo - Call Center Zeta"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-27">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="5000.00" Descripcion="Retiro ATM Universidad"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-28">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000002" Monto="650000.00" Descripcion="Salario abril - Constructora del Valle"/>
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="11000003" Monto="10000.00" Descripcion="Retiro en ventana sucursal Cartago"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-29">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000001" Monto="10000.00" Descripcion="Retiro ATM Plaza del Sol"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-04-30">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000008" Monto="30000.00" Descripcion="Retiro ATM Paseo de los Turistas"/>
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000009" Monto="610000.00" Descripcion="Salario abril - Cooperativa Agrícola Sur"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-02">
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="11000003" Monto="25000.00" Descripcion="Retiro en ventana sucursal Cartago"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="21000001" Monto="600.00" Descripcion="Depósito en ventana sucursal Central"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-03">
    <Movimientos Tipo="Compra" CodigoCuenta="11000007" Monto="15990.00" Descripcion="Restaurante El Fogón"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-04">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000007" Monto="520000.00" Descripcion="Salario abril - Hospital Enrique Baltodano"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-05">
    <Movimientos Tipo="Compra" CodigoCuenta="11000001" Monto="22300.00" Descripcion="Compra Walmart Desamparados"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-06">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000005" Monto="750000.00" Descripcion="De Hotel Montaña Azul - factura 238"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-09">
    <Movimientos Tipo="Compra" CodigoCuenta="11000002" Monto="249900.00" Descripcion="Compra Gollo Alajuela - refrigeradora"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-13">
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000009" Monto="250000.00" Descripcion="A María Fernanda Rojas - gastos casa"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-15">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000001" Monto="180000.00" Descripcion="Salario quincena mayo - Soluciones Tico S.A."/>
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="11000005" Monto="400000.00" Descripcion="Retiro en ventana sucursal Central"/>
    <Movimientos Tipo="Compra" CodigoCuenta="11000008" Monto="27300.00" Descripcion="Compra Walmart Guadalupe"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-18">
    <Movimientos Tipo="Compra" CodigoCuenta="11000004" Monto="23400.00" Descripcion="Compra Librería Internacional"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-20">
    <Persona TipoDocuIdentidad="1" Nombre="Sofía Herrera Calderón" ValorDocumentoIdentidad="115670234" FechaNacimiento="2003-06-19" Email="sofia.herrera@ejemplo.com" telefono1="84123390" telefono2="22835521"/>
    <Cuenta ValorDocumentoIdentidadDelCliente="115670234" TipoCuentaId="1" NumeroCuenta="11000010" FechaCreacion="2026-05-20" Saldo="0.00"/>
    <Usuario User="sherrera" Pass="Sofi2026*" EsAdministrador="0" ValorDocId="115670234"/>
    <UsuarioPuedeVer User="sherrera" NumeroCuenta="11000010"/>
    <Movimientos Tipo="Compra" CodigoCuenta="11000003" Monto="15600.00" Descripcion="Compra Tienda Universal Cartago"/>
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000010" Monto="50000.00" Descripcion="Depósito de apertura sucursal San Pedro"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-23">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000007" Monto="60000.00" Descripcion="Retiro ATM Liberia centro"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-24">
    <Movimientos Tipo="Compra" CodigoCuenta="11000010" Monto="6500.00" Descripcion="Compra Soda La Universitaria"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-26">
    <Movimientos Tipo="Compra" CodigoCuenta="11000009" Monto="132000.00" Descripcion="Compra Llantas del Pacífico"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-28">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000002" Monto="650000.00" Descripcion="Salario mayo - Constructora del Valle"/>
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="21000001" Monto="300.00" Descripcion="Retiro en ventana sucursal Central"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-29">
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000005" Monto="420000.00" Descripcion="A Distribuidora El Roble - factura 1102"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-30">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000009" Monto="610000.00" Descripcion="Salario mayo - Cooperativa Agrícola Sur"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-05-31">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000008" Monto="120000.00" Descripcion="Pago freelance diseño gráfico"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-02">
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000001" Monto="45000.00" Descripcion="A Rosa Jiménez - ayuda mensual"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-04">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000007" Monto="520000.00" Descripcion="Salario mayo - Hospital Enrique Baltodano"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-08">
    <Movimientos Tipo="Deposito Sinpe" CodigoCuenta="11000010" Monto="35000.00" Descripcion="Pago tutorías de cálculo"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-10">
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000004" Monto="20000.00" Descripcion="A Mateo Mora - préstamo"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-11">
    <Movimientos Tipo="Deposito Ventana" CodigoCuenta="11000005" Monto="900000.00" Descripcion="Depósito de ventas en ventana sucursal Central"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-12">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000002" Monto="80000.00" Descripcion="Retiro ATM Paseo de las Flores"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-14">
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000008" Monto="40000.00" Descripcion="A Laura Pérez - alquiler cuarto"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-18">
    <Movimientos Tipo="Compra" CodigoCuenta="11000001" Monto="9800.00" Descripcion="Compra Panadería Musmanni"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-20">
    <Movimientos Tipo="Compra" CodigoCuenta="21000001" Monto="120.75" Descripcion="Compra Booking.com"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-21">
    <Movimientos Tipo="Retiro Ventana" CodigoCuenta="11000009" Monto="200000.00" Descripcion="Retiro en ventana sucursal Pérez Zeledón"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-25">
    <Movimientos Tipo="Retiro Sinpe" CodigoCuenta="11000005" Monto="210000.00" Descripcion="A Tomás Sánchez - planilla junio"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-26">
    <Movimientos Tipo="Compra" CodigoCuenta="11000010" Monto="12900.00" Descripcion="Compra Librería Lehmann"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-27">
    <Movimientos Tipo="Compra" CodigoCuenta="11000002" Monto="41200.00" Descripcion="Restaurante Nuestra Tierra"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-29">
    <Movimientos Tipo="Compra" CodigoCuenta="11000007" Monto="89000.00" Descripcion="Compra Importadora Monge"/>
  </FechaOperacion>
  <FechaOperacion Fecha="2026-06-30">
    <Movimientos Tipo="Retiro ATM" CodigoCuenta="11000008" Monto="20000.00" Descripcion="Retiro ATM Paseo de los Turistas"/>
  </FechaOperacion>
</Operaciones>
';

-- Variables
DECLARE @idCorrida INT;
DECLARE @fechaInicio DATE;
DECLARE @fechaFin DATE;
DECLARE @fecha DATE;
DECLARE @fechaTexto VARCHAR(10);
DECLARE @flagDetener BIT = @false;
DECLARE @flagAltas BIT;
DECLARE @ultimoMov INT;
DECLARE @ultimaCuenta INT;
DECLARE @codigo INT;
DECLARE @codigoResultado INT = NULL;
DECLARE @idMovimiento INT;
DECLARE @idEstadoNuevo INT;
DECLARE @i INT;
DECLARE @cantMov INT;
DECLARE @idCuenta INT;
DECLARE @cierresHoy INT;
DECLARE @numeroCuenta VARCHAR(16);
DECLARE @tipoMov VARCHAR(64);
DECLARE @monto DECIMAL(18,2);
DECLARE @descripcion NVARCHAR(256);
DECLARE @referencia VARCHAR(128);
DECLARE @mensaje NVARCHAR(256);
DECLARE @movOk INT = 0;
DECLARE @movRechazados INT = 0;
DECLARE @cierresOk INT = 0;
DECLARE @fechasTerminadas INT = 0;

-- Rango de fechas: de la primera a la ultima fecha del XML
SELECT
    @fechaInicio = MIN(T.Nodo.value('@Fecha', 'DATE')),
    @fechaFin    = MAX(T.Nodo.value('@Fecha', 'DATE'))
FROM @xmlOperaciones.nodes('/Operaciones/FechaOperacion') AS T(Nodo);

-- Una corrida anterior que nunca llego al final quedo interrumpida
UPDATE dbo.CorridaSimulacion
SET CodigoResultado = @resultadoError,
    Mensaje = N'Interrumpida: no llego al final del script.'
WHERE FechaHoraFin IS NULL
  AND CodigoResultado IS NULL;

-- Registro de esta corrida
INSERT INTO dbo.CorridaSimulacion (FechaInicioXml, FechaFinXml)
VALUES (@fechaInicio, @fechaFin);

SET @idCorrida = SCOPE_IDENTITY();

-- Primera fecha pendiente: la mas antigua que no este terminada
SET @fecha = @fechaInicio;

WHILE (@fecha <= @fechaFin
       AND EXISTS (SELECT 1
                   FROM dbo.ControlSimulacion AS CS
                   WHERE CS.FechaOperacion = @fecha
                     AND CS.FlagTerminada = @true))
BEGIN
    SET @fecha = DATEADD(DAY, 1, @fecha);
END;

IF (@fecha > @fechaFin)
BEGIN
    SET @codigoResultado = @resultadoSinPendientes;
    SET @mensaje = N'Nada pendiente: todas las fechas ya estaban '
                 + N'procesadas. No se repitio nada.';
    PRINT @mensaje;
END;

BEGIN TRY
    WHILE (@fecha <= @fechaFin AND @flagDetener = @false)
    BEGIN
        SET @fechaTexto = CONVERT(VARCHAR(10), @fecha, 23);   -- yyyy-mm-dd

        -- Una fecha ya terminada no se vuelve a procesar
        IF NOT EXISTS (SELECT 1
                       FROM dbo.ControlSimulacion AS CS
                       WHERE CS.FechaOperacion = @fecha
                         AND CS.FlagTerminada = @true)
        BEGIN
            -- No se brinca una fecha: la anterior debe estar terminada
            IF (@fecha > @fechaInicio
                AND NOT EXISTS (SELECT 1
                                FROM dbo.ControlSimulacion AS CS
                                WHERE CS.FechaOperacion = DATEADD(DAY, -1, @fecha)
                                  AND CS.FlagTerminada = @true))
            BEGIN
                SET @codigo = 50500;
                SET @mensaje = N'Detenida: no se puede procesar ' + @fechaTexto
                             + N' porque la fecha anterior no esta terminada.';
                INSERT INTO dbo.ErrorBD (NumeroError, Procedimiento, Mensaje)
                VALUES (@codigo, N'Simulacion_TP3', @mensaje);
                PRINT @mensaje;
                SET @codigoResultado = @resultadoError;
                SET @flagDetener = @true;
            END;
        END;

        IF (@flagDetener = @false
            AND NOT EXISTS (SELECT 1
                            FROM dbo.ControlSimulacion AS CS
                            WHERE CS.FechaOperacion = @fecha
                              AND CS.FlagTerminada = @true))
        BEGIN
            SELECT @cantMov = COUNT(*)
            FROM @xmlOperaciones.nodes(
                '/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Movimientos'
            ) AS T(Nodo);

            -- Fila de control de la fecha: nueva, o reanudacion
            IF NOT EXISTS (SELECT 1
                           FROM dbo.ControlSimulacion AS CS
                           WHERE CS.FechaOperacion = @fecha)
            BEGIN
                INSERT INTO dbo.ControlSimulacion (
                    FechaOperacion,
                    IdCorridaSimulacion,
                    CantMovimientosXml
                )
                VALUES (@fecha, @idCorrida, @cantMov);
            END
            ELSE
            BEGIN
                UPDATE dbo.ControlSimulacion
                SET CantIntentos = CantIntentos + 1,
                    IdCorridaSimulacion = @idCorrida,
                    CodigoError = NULL
                WHERE FechaOperacion = @fecha;

                PRINT N'Reanudando la fecha ' + @fechaTexto;
            END;

            UPDATE dbo.CorridaSimulacion
            SET FechaDesde = @fecha
            WHERE Id = @idCorrida
              AND FechaDesde IS NULL;

            SELECT
                @flagAltas    = CS.FlagAltasProcesadas,
                @ultimoMov    = CS.UltimoMovimientoProcesado,
                @ultimaCuenta = CS.UltimaCuentaCerrada
            FROM dbo.ControlSimulacion AS CS
            WHERE CS.FechaOperacion = @fecha;

            -- 1. ALTAS DEL DIA (solo si no se hicieron antes)
            IF (@flagAltas = @false)
            BEGIN
                EXEC dbo.sp_CargarAltasDia
                    @inXml = @xmlOperaciones,
                    @inFecha = @fecha,
                    @outResultCode = @codigo OUTPUT;

                IF (@codigo = 0)
                BEGIN
                    -- Si el dia traia altas, el SP ya dejo esta marca dentro
                    -- de su transaccion; aqui queda para los dias sin altas.
                    UPDATE dbo.ControlSimulacion
                    SET FlagAltasProcesadas = @true
                    WHERE FechaOperacion = @fecha;
                END
                ELSE
                BEGIN
                    SET @mensaje = N'Detenida en ' + @fechaTexto
                                 + N': las altas fallaron con codigo '
                                 + ISNULL(CAST(@codigo AS NVARCHAR(10)), N'?');
                    UPDATE dbo.ControlSimulacion
                    SET CodigoError = @codigo
                    WHERE FechaOperacion = @fecha;
                    INSERT INTO dbo.ErrorBD (NumeroError, Procedimiento, Mensaje)
                    VALUES (@codigo, N'Simulacion_TP3', @mensaje);
                    PRINT @mensaje;
                    SET @codigoResultado = @resultadoError;
                    SET @flagDetener = @true;
                END;
            END;

            -- 2. MOVIMIENTOS DEL DIA, desde el que sigue al ultimo procesado
            SET @i = @ultimoMov + 1;

            WHILE (@i <= @cantMov AND @flagDetener = @false)
            BEGIN
                -- Referencia estable: fecha + posicion dentro del dia
                SET @referencia = @fechaTexto + '#' + CAST(@i AS VARCHAR(10));

                -- Si ya esta en dbo.Movimiento (se aplico pero la corrida no
                -- alcanzo a marcarlo en el control), no se vuelve a aplicar.
                IF EXISTS (SELECT 1
                           FROM dbo.Movimiento AS M
                           WHERE M.ReferenciaOrigen = @referencia)
                BEGIN
                    SET @codigo = @codigoMovYaRegistrado;
                END
                ELSE
                BEGIN
                    SET @numeroCuenta = @xmlOperaciones.value(
                        '(/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Movimientos[sql:variable("@i")]/@CodigoCuenta)[1]',
                        'VARCHAR(16)');
                    SET @tipoMov = @xmlOperaciones.value(
                        '(/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Movimientos[sql:variable("@i")]/@Tipo)[1]',
                        'VARCHAR(64)');
                    SET @monto = @xmlOperaciones.value(
                        '(/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Movimientos[sql:variable("@i")]/@Monto)[1]',
                        'DECIMAL(18,2)');
                    SET @descripcion = @xmlOperaciones.value(
                        '(/Operaciones/FechaOperacion[@Fecha=sql:variable("@fechaTexto")]/Movimientos[sql:variable("@i")]/@Descripcion)[1]',
                        'NVARCHAR(256)');

                    EXEC dbo.sp_AplicarMovimiento
                        @inNumeroCuenta = @numeroCuenta,
                        @inTipoMovimiento = @tipoMov,
                        @inFechaMovimiento = @fecha,
                        @inMonto = @monto,
                        @inDescripcion = @descripcion,
                        @inReferenciaOrigen = @referencia,
                        @outResultCode = @codigo OUTPUT,
                        @outIdMovimiento = @idMovimiento OUTPUT;
                END;

                IF (@codigo = 0 OR @codigo = @codigoMovYaRegistrado)
                BEGIN
                    SET @movOk = @movOk + 1;
                    UPDATE dbo.ControlSimulacion
                    SET UltimoMovimientoProcesado = @i,
                        CantMovimientosAplicados = CantMovimientosAplicados + 1
                    WHERE FechaOperacion = @fecha;
                END
                ELSE
                BEGIN
                    SET @movRechazados = @movRechazados + 1;
                    SET @mensaje = N'Movimiento rechazado ' + @referencia
                                 + N' cuenta ' + ISNULL(@numeroCuenta, N'?')
                                 + N' tipo ' + ISNULL(@tipoMov, N'?')
                                 + N' monto '
                                 + ISNULL(CAST(@monto AS NVARCHAR(30)), N'?')
                                 + N' codigo '
                                 + ISNULL(CAST(@codigo AS NVARCHAR(10)), N'?');
                    INSERT INTO dbo.ErrorBD (NumeroError, Procedimiento, Mensaje)
                    VALUES (@codigo, N'Simulacion_TP3', @mensaje);
                    UPDATE dbo.ControlSimulacion
                    SET UltimoMovimientoProcesado = @i,
                        CantMovimientosRechazados = CantMovimientosRechazados + 1
                    WHERE FechaOperacion = @fecha;
                END;

                -- Prueba de reanudacion: detenerse a proposito
                IF (@fecha = @pruebaFechaDetener
                    AND @i = @pruebaDetenerTrasMovimientos)
                BEGIN
                    SET @mensaje = N'Detenida a proposito (prueba) en '
                                 + @fechaTexto + N' tras el movimiento '
                                 + CAST(@i AS NVARCHAR(10));
                    PRINT @mensaje;
                    SET @codigoResultado = @resultadoPrueba;
                    SET @flagDetener = @true;
                END;

                SET @i = @i + 1;
            END;

            -- CIERRES DEL DIA: cuentas cuyo estado vence hoy, por Id (PK),
            --    empezando por la que sigue a la ultima cerrada
            SET @cierresHoy = 0;

            SELECT @idCuenta = MIN(E.IdCuenta)
            FROM dbo.EstadoCuenta AS E
            WHERE E.FechaFin = @fecha
              AND E.IdCuenta > @ultimaCuenta;

            WHILE (@idCuenta IS NOT NULL AND @flagDetener = @false)
            BEGIN
                SELECT @numeroCuenta = C.NumeroCuenta
                FROM dbo.Cuenta AS C
                WHERE C.Id = @idCuenta;

                -- Si ya existe el estado del periodo siguiente, este cierre ya
                -- se hizo (la corrida anterior no alcanzo a marcarlo).
                IF EXISTS (SELECT 1
                           FROM dbo.EstadoCuenta AS E
                           WHERE E.IdCuenta = @idCuenta
                             AND E.FechaInicio = DATEADD(DAY, 1, @fecha))
                BEGIN
                    SET @codigo = @codigoPeriodoCerrado;
                END
                ELSE
                BEGIN
                    EXEC dbo.sp_CerrarYAbrirEstadoCuenta
                        @inNumeroCuenta = @numeroCuenta,
                        @inFechaCierre = @fecha,
                        @outResultCode = @codigo OUTPUT,
                        @outIdNuevoEstadoCuenta = @idEstadoNuevo OUTPUT;
                END;

                IF (@codigo = 0 OR @codigo = @codigoPeriodoCerrado)
                BEGIN
                    SET @cierresOk = @cierresOk + 1;
                    SET @cierresHoy = @cierresHoy + 1;
                    UPDATE dbo.ControlSimulacion
                    SET UltimaCuentaCerrada = @idCuenta,
                        CantCierres = CantCierres + 1
                    WHERE FechaOperacion = @fecha;

                    -- Prueba de reanudacion: detenerse a proposito
                    IF (@fecha = @pruebaFechaDetener
                        AND @cierresHoy = @pruebaDetenerTrasCierres)
                    BEGIN
                        SET @mensaje = N'Detenida a proposito (prueba) en '
                                     + @fechaTexto + N' tras cerrar la cuenta '
                                     + @numeroCuenta;
                        PRINT @mensaje;
                        SET @codigoResultado = @resultadoPrueba;
                        SET @flagDetener = @true;
                    END;
                END
                ELSE
                BEGIN
                    SET @mensaje = N'Detenida en ' + @fechaTexto
                                 + N': el cierre de la cuenta '
                                 + ISNULL(@numeroCuenta, N'?')
                                 + N' fallo con codigo '
                                 + ISNULL(CAST(@codigo AS NVARCHAR(10)), N'?');
                    UPDATE dbo.ControlSimulacion
                    SET CodigoError = @codigo
                    WHERE FechaOperacion = @fecha;
                    INSERT INTO dbo.ErrorBD (NumeroError, Procedimiento, Mensaje)
                    VALUES (@codigo, N'Simulacion_TP3', @mensaje);
                    PRINT @mensaje;
                    SET @codigoResultado = @resultadoError;
                    SET @flagDetener = @true;
                END;

                SELECT @idCuenta = MIN(E.IdCuenta)
                FROM dbo.EstadoCuenta AS E
                WHERE E.FechaFin = @fecha
                  AND E.IdCuenta > @idCuenta;
            END;

            --LA FECHA QUEDA TERMINADA
            IF (@flagDetener = @false)
            BEGIN
                UPDATE dbo.ControlSimulacion
                SET FlagTerminada = @true,
                    FechaHoraFin = SYSDATETIME()
                WHERE FechaOperacion = @fecha;

                SET @fechasTerminadas = @fechasTerminadas + 1;

                UPDATE dbo.CorridaSimulacion
                SET FechaHasta = @fecha,
                    CantFechasTerminadas = @fechasTerminadas
                WHERE Id = @idCorrida;
            END;
        END;

        IF (@flagDetener = @false)
        BEGIN
            SET @fecha = DATEADD(DAY, 1, @fecha);
        END;
    END;
END TRY
BEGIN CATCH
    IF (@@TRANCOUNT > 0)
        ROLLBACK TRANSACTION;

    INSERT INTO dbo.ErrorBD (
        NumeroError, Severidad, Estado, Procedimiento, Linea, Mensaje
    )
    VALUES (
        ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(),
        ISNULL(ERROR_PROCEDURE(), N'Simulacion_TP3'), ERROR_LINE(),
        ERROR_MESSAGE()
    );

    UPDATE dbo.ControlSimulacion
    SET CodigoError = ERROR_NUMBER()
    WHERE FechaOperacion = @fecha;

    SET @mensaje = N'Detenida por error inesperado en '
                 + CONVERT(NVARCHAR(10), @fecha, 23) + N'. Ver dbo.ErrorBD.';
    PRINT @mensaje;
    SET @codigoResultado = @resultadoError;
    SET @flagDetener = @true;
END CATCH;

IF (@codigoResultado IS NULL)
BEGIN
    SET @codigoResultado = @resultadoCompleta;
    SET @mensaje = N'Completa: termino ' + CAST(@fechasTerminadas AS NVARCHAR(10))
                 + N' fechas, hasta ' + CONVERT(NVARCHAR(10), @fechaFin, 23) + N'.';
    PRINT @mensaje;
END;

UPDATE dbo.CorridaSimulacion
SET FechaHoraFin = SYSDATETIME(),
    CodigoResultado = @codigoResultado,
    Mensaje = @mensaje
WHERE Id = @idCorrida;

-- RESUMEN DE ESTA CORRIDA
SELECT
    CR.Id                   AS Corrida,
    CR.FechaDesde,
    CR.FechaHasta,
    CR.CantFechasTerminadas AS FechasTerminadas,
    @movOk                  AS MovimientosAplicados,
    @movRechazados          AS MovimientosRechazados,
    @cierresOk              AS Cierres,
    CR.CodigoResultado,
    CR.Mensaje
FROM dbo.CorridaSimulacion AS CR
WHERE CR.Id = @idCorrida;

-- TOTALES DE LA SIMULACION (todas las corridas juntas)
SELECT
    DATEDIFF(DAY, @fechaInicio, @fechaFin) + 1 AS FechasXml,
    (SELECT COUNT(*)
     FROM dbo.ControlSimulacion AS CS
     WHERE CS.FlagTerminada = @true)           AS FechasTerminadas,
    (SELECT MIN(CS.FechaOperacion)
     FROM dbo.ControlSimulacion AS CS
     WHERE CS.FlagTerminada = @false)          AS FechaAMedias,
    (SELECT ISNULL(SUM(CS.CantMovimientosAplicados), 0)
     FROM dbo.ControlSimulacion AS CS)         AS MovimientosAplicados,
    (SELECT ISNULL(SUM(CS.CantMovimientosRechazados), 0)
     FROM dbo.ControlSimulacion AS CS)         AS MovimientosRechazados,
    (SELECT ISNULL(SUM(CS.CantCierres), 0)
     FROM dbo.ControlSimulacion AS CS)         AS Cierres;

SELECT C.NumeroCuenta, C.FechaCreacion, C.Saldo,
       (SELECT COUNT(*) FROM dbo.EstadoCuenta E WHERE E.IdCuenta = C.Id) AS Estados
FROM dbo.Cuenta AS C
ORDER BY C.Id;

SELECT TM.Nombre AS TipoMovimiento, COUNT(*) AS Cantidad
FROM dbo.Movimiento AS M
INNER JOIN dbo.TipoMovimiento AS TM
    ON TM.Id = M.IdTipoMovimiento
GROUP BY TM.Nombre 
ORDER BY TM.Nombre;

SELECT TOP (20) Id, NumeroError, Mensaje FROM dbo.ErrorBD ORDER BY Id DESC;
