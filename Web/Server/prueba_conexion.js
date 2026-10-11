// Prueba técnica: Node recupera @outResultCode, dos resultsets y un parámetro XML
// Se ejecuta con:  node prueba_conexion.js
import { ejecutarSP, sql } from './Db.js';

try {
  console.log('--- 1. OUTPUT y dos resultsets ---');
  const r1 = await ejecutarSP('dbo.sp_PruebaContrato', {
    inTexto: [sql.VarChar(50), 'hola'],
  });
  console.log('outResultCode:', r1.codigo);
  console.log('Resultset 1:', r1.recordsets[0]);
  console.log('Resultset 2:', r1.recordsets[1]);

  console.log('--- 2. Parámetro XML ---');
  const xml = '<p><b id="1" pct="70"/><b id="2" pct="30"/></p>';
  const r2 = await ejecutarSP('dbo.sp_PruebaXml', { inXml: [sql.Xml, xml] });
  console.log('outResultCode:', r2.codigo);
  console.log('Filas leídas del XML:', r2.recordsets[0]);

  console.log('--- Prueba terminada ---');
  process.exit(0);
} catch (error) {
  console.error('ERROR:', error.message);
  process.exit(1);
}