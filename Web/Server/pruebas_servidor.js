// =============================================================================
// pruebas_servidor.js — PRUEBAS AUTOMÁTICAS DEL SERVIDOR (no necesita SQL Server)
// Se ejecuta con:  node pruebas_servidor.js
// Reemplaza la base de datos por una "falsa" que imita lo que devuelven los SP
// =============================================================================
import { crearApp } from './app.js';

// ---- Base de datos falsa --------------------------------------------------
const llamadas = [];                       // registro de cada SP invocado
let fallarSiempre = false;                 // para simular SQL Server caído
const USUARIOS = { jaguero: { id: 2, clave: 'LaFacil', admin: 0 }, fquiros: { id: 4, clave: 'Prof', admin: 1 } };
const CUENTAS = { 2: ['11000001', '11000017'] };

async function ejecutarSPFalso(nombre, e) {
  const v = (k) => e[k]?.[1];              // valor de un parámetro
  llamadas.push({ nombre, params: Object.fromEntries(Object.entries(e).map(([k, [, x]]) => [k, x])) });
  if (fallarSiempre) throw new Error('Login failed for user app_tp2 (detalle interno)');
  if (nombre === 'dbo.sp_IniciarSesion') {
    const u = USUARIOS[v('inNombreUsuario')];
    if (!u || u.clave !== v('inClave')) return { codigo: 50001, recordsets: [] };
    return { codigo: 0, recordsets: [[{ IdUsuario: u.id, EsAdministrador: u.admin }]] };
  }
  if (nombre === 'dbo.sp_ListarCuentasUsuario') {
    const filas = (CUENTAS[v('inIdUsuario')] ?? []).map((n, i) => ({ IdCuenta: i + 1, NumeroCuenta: n, Saldo: 1000, NombreTipoCuenta: 'Proletario' }));
    return { codigo: 0, recordsets: [filas] };
  }
  if (nombre === 'dbo.sp_ConsultarEstadosCuenta') {
    const propia = (CUENTAS[v('inIdUsuario')] ?? []).includes(v('inNumeroCuenta'));
    if (!propia && v('inIdUsuario') !== 4) return { codigo: 50002, recordsets: [] };
    const filas = Array.from({ length: 8 }, (_, i) => ({
      IdEstadoCuenta: i + 1, FechaInicio: new Date('2026-08-13T00:00:00Z'),
      FechaFin: new Date('2026-09-12T00:00:00Z'), FechaEmision: new Date('2026-09-13T00:00:00Z'),
      SaldoInicial: 1, SaldoFinal: 2, SaldoMinimo: 1, InteresesAcumulados: 0,
      CantRetiros: 0, CantDepositos: 0, CantSinpeEntrantes: 0, CantSinpeSalientes: 0 }));
    return { codigo: 0, recordsets: [filas] };
  }
  if (nombre === 'dbo.sp_CerrarSesion') return { codigo: 0, recordsets: [] };
  throw new Error('SP no previsto: ' + nombre);
}

// ---- Arranque y cliente de prueba (conserva la cookie como un navegador) ---
const app = crearApp(ejecutarSPFalso, { secreto: 'secreto-de-prueba' });
const servidor = app.listen(0);
const base = `http://localhost:${servidor.address().port}`;
let cookie = '';
async function pedir(metodo, ruta, cuerpo) {
  const r = await fetch(base + ruta, {
    method: metodo,
    headers: { 'Content-Type': 'application/json', ...(cookie ? { Cookie: cookie } : {}) },
    body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
  });
  const set = r.headers.get('set-cookie');
  if (set) cookie = set.split(';')[0];
  return { status: r.status, json: await r.json(), set };
}

// ---- Mini marco de pruebas ---------------------------------------------------
let ok = 0, mal = 0;
function comprobar(nombre, condicion, detalle = '') {
  if (condicion) { ok++; console.log('  OK   ', nombre); }
  else { mal++; console.log('  FALLA', nombre, detalle); }
}

console.log('1. Sin sesión');
let r = await pedir('GET', '/api/cuentas');
comprobar('GET /api/cuentas sin sesión -> 401', r.status === 401);
comprobar('no se llamó a ningún SP', llamadas.length === 0);
r = await pedir('GET', '/api/cuentas/11000001/estados');
comprobar('estados sin sesión -> 401', r.status === 401 && llamadas.length === 0);
r = await pedir('POST', '/api/logout');
comprobar('logout sin sesión -> 401', r.status === 401 && llamadas.length === 0);

console.log('2. Login incorrecto');
r = await pedir('POST', '/api/login', { nombreUsuario: 'jaguero', clave: 'lafacil' });
comprobar('clave mala -> 401, código 50001', r.status === 401 && r.json.codigo === 50001);
comprobar('no se crea cookie de sesión', !r.set);
const antes = llamadas.length;
r = await pedir('POST', '/api/login', { nombreUsuario: { $ne: 1 }, clave: ['x'] });
comprobar('datos que no son texto -> 401 sin llamar al SP', r.status === 401 && llamadas.length === antes);
r = await pedir('POST', '/api/login', { nombreUsuario: 'x'.repeat(65), clave: 'a' });
comprobar('usuario de 65 caracteres -> 401 sin llamar al SP', r.status === 401 && llamadas.length === antes);
r = await pedir('POST', '/api/login', {});
comprobar('cuerpo vacío -> 401', r.status === 401);

console.log('3. Login correcto');
r = await pedir('POST', '/api/login', { nombreUsuario: 'jaguero', clave: 'LaFacil' });
const cookieLogin = cookie;
comprobar('login -> 200 y usuario', r.status === 200 && r.json.ok && r.json.usuario.idUsuario === 2 && r.json.usuario.esAdministrador === false);
comprobar('cookie httpOnly', /HttpOnly/i.test(r.set ?? ''));
const spLogin = llamadas.at(-1);
comprobar('el SP recibió la IP del servidor, con largo <= 45', typeof spLogin.params.inIP === 'string' && spLogin.params.inIP.length <= 45);
r = await pedir('GET', '/api/sesion');
comprobar('GET /api/sesion -> usuario en sesión', r.status === 200 && r.json.usuario.nombreUsuario === 'jaguero');

console.log('4. Cuentas y estados');
r = await pedir('GET', '/api/cuentas');
comprobar('cuentas -> 2 filas', r.status === 200 && r.json.datos.length === 2 && r.json.datos[0].NumeroCuenta === '11000001');
r = await pedir('GET', '/api/cuentas?idUsuario=4');
comprobar('?idUsuario=4 en la URL se ignora (sigue siendo el usuario 2)', llamadas.at(-1).params.inIdUsuario === 2 && r.json.datos.length === 2);
r = await pedir('GET', '/api/cuentas/11000001/estados');
comprobar('estados propios -> 8 filas', r.status === 200 && r.json.datos.length === 8);
comprobar('fechas como texto AAAA-MM-DD', r.json.datos[0].FechaFin === '2026-09-12' && r.json.datos[0].FechaEmision === '2026-09-13');
r = await pedir('GET', '/api/cuentas/11000002/estados');
comprobar('cuenta ajena -> 403, código 50002', r.status === 403 && r.json.codigo === 50002);
const n = llamadas.length;
r = await pedir('GET', '/api/cuentas/1%27%20OR%201%3D1--/estados');
comprobar('número de cuenta con forma rara -> 403 sin llamar al SP', r.status === 403 && llamadas.length === n);
r = await pedir('GET', '/api/beneficiarios');
comprobar('ruta aún no conectada -> 501', r.status === 501 && r.json.ok === false);

console.log('5. Logout');
r = await pedir('POST', '/api/logout');
comprobar('logout -> 200', r.status === 200 && r.json.ok);
comprobar('sp_CerrarSesion recibió el Id de la sesión (2)', llamadas.at(-1).nombre === 'dbo.sp_CerrarSesion' && llamadas.at(-1).params.inIdUsuario === 2);
r = await fetch(base + '/api/cuentas', { headers: { Cookie: cookieLogin } });
comprobar('la cookie vieja ya no sirve -> 401', r.status === 401);

console.log('6. Sesión nueva en cada login');
cookie = '';
await pedir('GET', '/api/sesion');               // sin sesión: no debe crear cookie
r = await pedir('POST', '/api/login', { nombreUsuario: 'fquiros', clave: 'Prof' });
comprobar('administrador entra con esAdministrador = true', r.json.usuario.esAdministrador === true);
comprobar('el identificador de sesión es distinto del anterior', cookie !== cookieLogin);

console.log('7. Errores internos');
fallarSiempre = true;
r = await pedir('GET', '/api/cuentas');
comprobar('SQL Server caído -> 500 con mensaje genérico', r.status === 500 && r.json.mensaje === 'Ocurrió un error inesperado.');
comprobar('el detalle interno NO llega al navegador', !JSON.stringify(r.json).includes('app_tp2'));
fallarSiempre = false;

console.log(`\nResultado: ${ok} correctas, ${mal} con falla`);
servidor.close();
process.exit(mal === 0 ? 0 : 1);