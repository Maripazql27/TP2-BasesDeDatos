
import { crearApp } from './app.js';

// ---- Base de datos falsa --------------------------------------------------
const llamadas = [];                       // registro de cada SP invocado
let fallarSiempre = false;                 // para simular SQL Server caído
let codigoSoloActualizar = 0;               // código solo para sp_ActualizarBeneficiario (prueba de fallo a medias)
let codigoForzado = 0;                     // código que devolverán los SP de beneficiarios
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
  if (nombre === 'dbo.sp_ListarParentezcos') return { codigo: 0, recordsets: [[{ Id: 1, Nombre: 'Padre' }, { Id: 2, Nombre: 'Madre' }]] };
  if (nombre === 'dbo.sp_ListarTiposDocumento') return { codigo: 0, recordsets: [[{ Id: 1, Nombre: 'Cedula Nacional' }]] };
  if (nombre === 'dbo.sp_ListarBeneficiarios') {
    return codigoForzado !== 0 ? { codigo: codigoForzado, recordsets: [] } : { codigo: 0, recordsets: [
      [{ IdBeneficiario: 7, Nombre: 'Ana', ValorDocumentoIdentidad: '1', FechaNacimiento: new Date('1990-05-10T00:00:00Z'), Email: 'a@b.c', IdParentezco: 2, NombreParentezco: 'Madre', Porcentaje: 60 },
       { IdBeneficiario: 8, Nombre: 'Luis', ValorDocumentoIdentidad: '2', FechaNacimiento: new Date('1992-08-21T00:00:00Z'), Email: 'l@b.c', IdParentezco: 1, NombreParentezco: 'Padre', Porcentaje: 30 }],
      [{ SumaPorcentajes: 90, CantidadBeneficiarios: 2 }]] };
  }
  if (nombre === 'dbo.sp_ActualizarBeneficiario' && codigoSoloActualizar !== 0) return { codigo: codigoSoloActualizar, recordsets: [] };
  if (['dbo.sp_AgregarBeneficiario', 'dbo.sp_ActualizarBeneficiario', 'dbo.sp_EliminarBeneficiario'].includes(nombre)) {
    return { codigo: codigoForzado, recordsets: [] };
  }
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

console.log('8. Beneficiarios y catálogos');
cookie = '';
r = await pedir('GET', '/api/catalogos/parentezcos');
comprobar('catálogo sin sesión -> 401', r.status === 401);
r = await pedir('POST', '/api/login', { nombreUsuario: 'jaguero', clave: 'LaFacil' });
r = await pedir('GET', '/api/catalogos/parentezcos');
comprobar('parentescos -> lista { Id, Nombre }', r.status === 200 && r.json.datos[0].Nombre === 'Padre');
r = await pedir('GET', '/api/catalogos/tipos-documento');
comprobar('tipos de documento -> lista', r.status === 200 && r.json.datos.length === 1);
r = await pedir('GET', '/api/cuentas/11000001/beneficiarios');
comprobar('listar -> beneficiarios + resumen, fecha como AAAA-MM-DD', r.status === 200 && r.json.beneficiarios[0].FechaNacimiento === '1990-05-10' && r.json.resumen.SumaPorcentajes === 90);
const antesRaro = llamadas.length;
r = await pedir('GET', '/api/cuentas/abc/beneficiarios');
comprobar('número de cuenta raro -> 403 sin llamar al SP', r.status === 403 && llamadas.length === antesRaro);

const alta = { idTipoDocuIdentidad: 1, valorDocumentoIdentidad: '123456789', nombre: 'Luis Mora', fechaNacimiento: '1992-08-21',
  email: 'luis@correo.com', telefono1: '88887777', telefono2: '22223333', idParentezco: 5, porcentaje: 40 };
codigoForzado = 0;
r = await pedir('POST', '/api/cuentas/11000001/beneficiarios', { ...alta, idUsuario: 4 });
comprobar('agregar válido -> 200', r.status === 200 && r.json.ok);
const sp = llamadas.at(-1);
comprobar('el SP recibió el IdUsuario de la SESIÓN (2), no el del cuerpo (4)', sp.nombre === 'dbo.sp_AgregarBeneficiario' && sp.params.inIdUsuario === 2);
comprobar('el SP recibió los 11 parámetros esperados', Object.keys(sp.params).length === 11 && sp.params.inPorcentaje === 40 && sp.params.inNumeroCuenta === '11000001');

let n2 = llamadas.length;
for (const [nombre, malo] of [
  ['porcentaje como texto', { ...alta, porcentaje: '40' }],
  ['porcentaje decimal', { ...alta, porcentaje: 40.5 }],
  ['teléfono con letras', { ...alta, telefono1: '88a' }],
  ['fecha mal formada', { ...alta, fechaNacimiento: '21/08/1992' }],
  ['nombre de 65 caracteres', { ...alta, nombre: 'x'.repeat(65) }],
  ['falta el email', { ...alta, email: undefined }],
]) {
  r = await pedir('POST', '/api/cuentas/11000001/beneficiarios', malo);
  comprobar(`agregar con ${nombre} -> 400 (50007) sin llamar al SP`, r.status === 400 && r.json.codigo === 50007 && llamadas.length === n2);
}

for (const [codigo, http] of [[50003, 409], [50004, 400], [50005, 409], [50007, 400], [50008, 400], [50009, 400], [50002, 403]]) {
  codigoForzado = codigo;
  r = await pedir('POST', '/api/cuentas/11000001/beneficiarios', alta);
  comprobar(`el SP devuelve ${codigo} -> HTTP ${http} con mensaje`, r.status === http && r.json.codigo === codigo && r.json.ok === false && r.json.mensaje);
}
codigoForzado = 0;

// ---- Porcentajes en bloque (no existe SP en lote: el servidor llama a sp_ActualizarBeneficiario uno por uno)
const actualizaciones = (desde) => llamadas.slice(desde).filter((l) => l.nombre === 'dbo.sp_ActualizarBeneficiario');
let desde = llamadas.length;
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 50 }, { idBeneficiario: 8, porcentaje: 50 }] });
let act = actualizaciones(desde);
comprobar('porcentajes 60/30 -> 50/50: 200', r.status === 200 && r.json.ok);
comprobar('primero baja el que baja (7: 60->50) y después el que sube (8: 30->50)', act.length === 2 && act[0].params.inIdBeneficiario === 7 && act[1].params.inIdBeneficiario === 8);
comprobar('cada llamada trae nombre y parentesco ACTUALES y el porcentaje nuevo', act[0].params.inNombre === 'Ana' && act[0].params.inIdParentezco === 2 && act[0].params.inPorcentaje === 50 && act[1].params.inNombre === 'Luis' && act[1].params.inPorcentaje === 50);
comprobar('el IdUsuario sale de la sesión (2)', act.every((a) => a.params.inIdUsuario === 2));
desde = llamadas.length;
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 80 }, { idBeneficiario: 8, porcentaje: 20 }] });
act = actualizaciones(desde);
comprobar('60/30 -> 80/20: baja primero el 8 (30->20) y luego sube el 7', r.status === 200 && act.length === 2 && act[0].params.inIdBeneficiario === 8 && act[1].params.inIdBeneficiario === 7);
desde = llamadas.length;
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 60 }, { idBeneficiario: 8, porcentaje: 40 }] });
act = actualizaciones(desde);
comprobar('solo cambia uno (8: 30->40): una sola llamada al SP', r.status === 200 && act.length === 1 && act[0].params.inIdBeneficiario === 8);
desde = llamadas.length;
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 60 }, { idBeneficiario: 8, porcentaje: 30 }] });
comprobar('sin cambios -> 200 y ninguna llamada de actualización', r.status === 200 && actualizaciones(desde).length === 0);
n2 = llamadas.length;
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 70 }, { idBeneficiario: 8, porcentaje: 40 }] });
comprobar('suma 110 -> 400 (50009) sin llamar a ningún SP', r.status === 400 && r.json.codigo === 50009 && llamadas.length === n2);
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 101 }, { idBeneficiario: 8, porcentaje: 0 }] });
comprobar('porcentaje 101 -> 400 (50004) sin llamar a ningún SP', r.status === 400 && r.json.codigo === 50004 && llamadas.length === n2);
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 50 }, { idBeneficiario: 7, porcentaje: 50 }] });
comprobar('ids repetidos -> 400 (50007)', r.status === 400 && r.json.codigo === 50007 && llamadas.length === n2);
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 50 }] });
comprobar('lista que no trae a todos los activos -> 400 (50007) y no actualiza nada', r.status === 400 && r.json.codigo === 50007 && actualizaciones(n2).length === 0);
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 50 }, { idBeneficiario: 99, porcentaje: 50 }] });
comprobar('id que no es de la cuenta -> 400 (50007)', r.status === 400 && actualizaciones(n2).length === 0);
codigoForzado = 50002;
r = await pedir('PUT', '/api/cuentas/11000017/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 50 }, { idBeneficiario: 8, porcentaje: 50 }] });
comprobar('sin acceso a la cuenta (el listado devuelve 50002) -> 403', r.status === 403);
codigoForzado = 0;
codigoSoloActualizar = 50006;
desde = llamadas.length;
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: 7, porcentaje: 50 }, { idBeneficiario: 8, porcentaje: 50 }] });
comprobar('si un SP falla se detiene y devuelve su código (50006 -> 404)', r.status === 404 && actualizaciones(desde).length === 1);
codigoSoloActualizar = 0;
n2 = llamadas.length;
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [{ idBeneficiario: '7"/><x', porcentaje: 70 }] });
comprobar('id no numérico -> 400 sin llamar al SP', r.status === 400 && llamadas.length === n2);
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [1, 2, 3, 4].map((i) => ({ idBeneficiario: i, porcentaje: 25 })) });
comprobar('4 porcentajes -> 400 sin llamar al SP', r.status === 400 && llamadas.length === n2);
r = await pedir('PUT', '/api/cuentas/11000001/porcentajes', { porcentajes: [] });
comprobar('lista vacía -> 400 sin llamar al SP', r.status === 400 && llamadas.length === n2);

r = await pedir('PUT', '/api/beneficiarios/7', { nombre: 'Ana M', idParentezco: 2, porcentaje: 60 });
comprobar('actualizar nombre/parentesco -> 200, con los 5 parámetros del SP', r.status === 200 && llamadas.at(-1).params.inIdBeneficiario === 7 && llamadas.at(-1).params.inIdUsuario === 2 && llamadas.at(-1).params.inPorcentaje === 60 && Object.keys(llamadas.at(-1).params).length === 5);
n2 = llamadas.length;
r = await pedir('PUT', '/api/beneficiarios/7', { nombre: 'Ana M', idParentezco: 2 });
comprobar('actualizar sin porcentaje -> 400 sin llamar al SP', r.status === 400 && llamadas.length === n2);
r = await pedir('PUT', '/api/beneficiarios/abc', { nombre: 'Ana', idParentezco: 2, porcentaje: 60 });
comprobar('id no numérico -> 400 sin llamar al SP', r.status === 400);
codigoForzado = 50006;
r = await pedir('PUT', '/api/beneficiarios/99', { nombre: 'Ana', idParentezco: 2, porcentaje: 60 });
comprobar('beneficiario inexistente (50006) -> 404', r.status === 404 && r.json.codigo === 50006);
r = await pedir('DELETE', '/api/beneficiarios/99');
comprobar('eliminar inexistente -> 404', r.status === 404);
codigoForzado = 0;
r = await pedir('DELETE', '/api/beneficiarios/7');
comprobar('eliminar -> 200', r.status === 200 && llamadas.at(-1).nombre === 'dbo.sp_EliminarBeneficiario');
r = await pedir('GET', '/api/ruta-que-no-existe');
comprobar('ruta inexistente -> 501', r.status === 501);

console.log(`\nResultado: ${ok} correctas, ${mal} con falla`);
servidor.close();
process.exit(mal === 0 ? 0 : 1);