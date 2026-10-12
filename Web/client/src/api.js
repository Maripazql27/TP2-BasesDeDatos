
// api.js — CAPA DE ACCESO A DATOS DE LA WEB
// ESTADO DE LA CONEXIÓN
//     iniciarSesion          -> POST /api/login   -> sp_IniciarSesion
//     cerrarSesion           -> POST /api/logout  -> sp_CerrarSesion
//     obtenerSesion          -> GET  /api/sesion  (¿quién tiene sesión?)
//     listarCuentas          -> GET  /api/cuentas -> sp_ListarCuentasUsuario
//     consultarEstados       -> GET  /api/cuentas/:numero/estados
//                                                 -> sp_ConsultarEstadosCuenta
const USAR_MOCK_BENEFICIARIOS = true;

// Simula la demora de una petición real (milisegundos) para ver "Cargando...".
const esperar = (ms) => new Promise((resolver) => setTimeout(resolver, ms));



// Hace UNA petición al servidor y siempre devuelve un objeto { ok, ... }.
//   - Usa direcciones relativas ('/api/...'): en desarrollo, Vite las reenvía
//     al servidor Express (ver "proxy" en vite.config.js). Como el navegador
//     cree que habla con un solo sitio, la cookie de sesión viaja sola.
//   - Si el servidor no responde (apagado, sin red), no lanza error: devuelve
//     { ok:false, codigo:50000, mensaje } para que la pantalla lo muestre.
async function pedir(metodo, ruta, cuerpo) {
  try {
    const respuesta = await fetch(ruta, {
      method: metodo,
      headers: cuerpo ? { 'Content-Type': 'application/json' } : undefined,
      body: cuerpo ? JSON.stringify(cuerpo) : undefined,
      credentials: 'same-origin', // envía la cookie de sesión
    });
    // El servidor siempre responde JSON con { ok, ... }, también en los errores
    // (401, 403, 500). Si por algo no fuera JSON, se cae al catch.
    return await respuesta.json();
  } catch {
    return { ok: false, codigo: 50000, mensaje: 'No se pudo conectar con el servidor.' };
  }
}

// Login. El servidor llama a sp_IniciarSesion y, si todo sale bien, guarda la
// sesión. Devuelve { ok:true, usuario:{ idUsuario, nombreUsuario, esAdministrador } }.
export function iniciarSesion(nombreUsuario, clave) {
  return pedir('POST', '/api/login', { nombreUsuario, clave });
}

// Cierra la sesión: el servidor registra el logout (sp_CerrarSesion) y destruye la sesión.
export function cerrarSesion() {
  return pedir('POST', '/api/logout');
}

// Pregunta al servidor si ya hay una sesión abierta. Se usa al cargar la página
// para que recargar no obligue a iniciar sesión otra vez.
export function obtenerSesion() {
  return pedir('GET', '/api/sesion');
}

// Cuentas del usuario con sesión. El Id del usuario
// NO se envía: el servidor lo toma de la sesión.
export function listarCuentas() {
  return pedir('GET', '/api/cuentas');
}

// Hasta 8 estados de cuenta, del más reciente al más antiguo
// encodeURIComponent protege la dirección si el
// número trajera caracteres raros.
export function consultarEstados(numeroCuenta) {
  return pedir('GET', `/api/cuentas/${encodeURIComponent(numeroCuenta)}/estados`);
}


// Código de error -> mensaje que ve el usuario. En la versión real el
// servidor traducirá el @outResultCode del SP con esta misma tabla.
const MENSAJES = {
  50000: 'Ocurrió un error inesperado.',
  50002: 'No tiene acceso a esta cuenta.',
  50003: 'La cuenta ya tiene 3 beneficiarios activos.',
  50004: 'El porcentaje debe ser un entero entre 1 y 100.',
  50005: 'Esa persona ya es beneficiaria activa de esta cuenta.',
  50006: 'El beneficiario no existe o ya está inactivo.',
  50007: 'Hay datos inválidos. Revise el formulario.',
  50008: 'El parentesco o el tipo de documento no existe.',
  50009: 'Los porcentajes de todos los beneficiarios deben sumar exactamente 100.',
};

// Construye la respuesta de error estándar a partir de un código.
const fallo = (codigo) => ({ ok: false, codigo, mensaje: MENSAJES[codigo] });

// Catálogos falsos (los reales vienen del XML y los entrega un SP).
const PARENTEZCOS = [
  { Id: 1, Nombre: 'Padre' },
  { Id: 2, Nombre: 'Madre' },
  { Id: 3, Nombre: 'Hijo' },
  { Id: 4, Nombre: 'Hija' },
  { Id: 5, Nombre: 'Hermano' },
  { Id: 6, Nombre: 'Hermana' },
  { Id: 7, Nombre: 'amigo' },
  { Id: 8, Nombre: 'amiga' },
];

const TIPOS_DOCUMENTO = [
  { Id: 1, Nombre: 'Cedula Nacional' },
  { Id: 2, Nombre: 'Cedula Residente' },
  { Id: 3, Nombre: 'Pasaporte' },
  { Id: 4, Nombre: 'Cedula Juridica' },
  { Id: 5, Nombre: 'Permiso de Trabajo' },
  { Id: 6, Nombre: 'Cedula Extranjera' },
];

// "Base de datos" falsa en memoria. Se pierde al recargar la página.
// Activo = false significa desactivado (eliminación lógica: no se borra).
let siguienteIdBeneficiario = 4;
const beneficiariosMock = [
  { IdBeneficiario: 1, NumeroCuenta: '11000001', Nombre: 'Ana Mora Solano',
    ValorDocumentoIdentidad: '100000001', FechaNacimiento: '1990-05-10',
    Email: 'ana@correo.com', IdParentezco: 6, Porcentaje: 60, Activo: true },
  { IdBeneficiario: 2, NumeroCuenta: '11000001', Nombre: 'Luis Mora Solano',
    ValorDocumentoIdentidad: '100000002', FechaNacimiento: '1992-08-21',
    Email: 'luis@correo.com', IdParentezco: 5, Porcentaje: 40, Activo: true },
  { IdBeneficiario: 3, NumeroCuenta: '11000002', Nombre: 'Rosa Vega Rojas',
    ValorDocumentoIdentidad: '100000003', FechaNacimiento: '1985-01-02',
    Email: 'rosa@correo.com', IdParentezco: 2, Porcentaje: 50, Activo: true },
];

// Beneficiarios ACTIVOS de una cuenta (los desactivados no cuentan).
const activosDe = (numeroCuenta) =>
  beneficiariosMock.filter((b) => b.NumeroCuenta === numeroCuenta && b.Activo);

// --- Validaciones ---
// En el sistema real las hace el SP (la base de datos es la que manda);
// aquí se copian para que el simulador responda igual que el real.
const porcentajeValido = (p) => Number.isInteger(p) && p >= 1 && p <= 100;

function validarNombreParentesco(d) {
  if (!d.nombre || d.nombre.length > 64) return 50007;
  if (!PARENTEZCOS.some((p) => p.Id === d.idParentezco)) return 50008;
  return 0; // 0 = sin error
}

function validarAlta(d) {
  // Texto formado solo por dígitos y de largo máximo "max".
  const soloDigitos = (t, max) => /^[0-9]+$/.test(t) && t.length <= max;
  if (!soloDigitos(d.valorDocumentoIdentidad, 32)) return 50007;
  if (!soloDigitos(d.telefono1, 16) || !soloDigitos(d.telefono2, 16)) return 50007;
  if (!d.fechaNacimiento || !d.email.includes('@')) return 50007;
  if (!TIPOS_DOCUMENTO.some((t) => t.Id === d.idTipoDocuIdentidad)) return 50008;
  return 0;
}

// Real: sp_ListarParentezcos (para el desplegable de parentesco).
export async function listarParentezcos() {
  if (!USAR_MOCK_BENEFICIARIOS) return pedir('GET', '/api/catalogos/parentezcos');
  if (USAR_MOCK_BENEFICIARIOS) {
    await esperar(100);
    return { ok: true, datos: PARENTEZCOS };
  }
}

// Real: sp_ListarTiposDocumento (para el desplegable de tipo de documento).
export async function listarTiposDocumento() {
  if (!USAR_MOCK_BENEFICIARIOS) return pedir('GET', '/api/catalogos/tipos-documento');
  if (USAR_MOCK_BENEFICIARIOS) {
    await esperar(100);
    return { ok: true, datos: TIPOS_DOCUMENTO };
  }
}

// Devuelve lo mismo que sus DOS consultas:
//   1) la lista de beneficiarios activos       -> "beneficiarios"
//   2) una fila con la suma y la cantidad      -> "resumen"
// La suma se devuelve aunque no haya beneficiarios (0), para la alerta.
export async function listarBeneficiarios(numeroCuenta) {
  if (!USAR_MOCK_BENEFICIARIOS) {
    return pedir('GET', `/api/cuentas/${encodeURIComponent(numeroCuenta)}/beneficiarios`);
  }
  if (USAR_MOCK_BENEFICIARIOS) {
    await esperar(200);
    const activos = activosDe(numeroCuenta);
    const beneficiarios = activos.map((b) => ({
      IdBeneficiario: b.IdBeneficiario,
      Nombre: b.Nombre,
      ValorDocumentoIdentidad: b.ValorDocumentoIdentidad,
      FechaNacimiento: b.FechaNacimiento,
      Email: b.Email,
      IdParentezco: b.IdParentezco,
      NombreParentezco: PARENTEZCOS.find((p) => p.Id === b.IdParentezco).Nombre,
      Porcentaje: b.Porcentaje,
    }));
    const resumen = {
      SumaPorcentajes: activos.reduce((suma, b) => suma + b.Porcentaje, 0),
      CantidadBeneficiarios: activos.length,
    };
    return { ok: true, beneficiarios, resumen };
  }
}

// Se valida en este orden y se devuelve
// el primer error encontrado.
export async function agregarBeneficiario(numeroCuenta, d) {
  if (!USAR_MOCK_BENEFICIARIOS) {
    return pedir('POST', `/api/cuentas/${encodeURIComponent(numeroCuenta)}/beneficiarios`, d);
  }
  if (USAR_MOCK_BENEFICIARIOS) {
    await esperar(200);
    let codigo = validarNombreParentesco(d);
    if (codigo === 0 && !porcentajeValido(d.porcentaje)) codigo = 50004;
    if (codigo === 0) codigo = validarAlta(d);
    // Máximo 3 beneficiarios activos por cuenta.
    if (codigo === 0 && activosDe(numeroCuenta).length >= 3) codigo = 50003;
    // La misma persona no puede ser beneficiaria activa dos veces en la cuenta.
    if (codigo === 0 && activosDe(numeroCuenta).some(
      (b) => b.ValorDocumentoIdentidad === d.valorDocumentoIdentidad)) codigo = 50005;
    if (codigo !== 0) return fallo(codigo);
    beneficiariosMock.push({
      IdBeneficiario: siguienteIdBeneficiario++, // el real es IDENTITY
      NumeroCuenta: numeroCuenta,
      Nombre: d.nombre,
      ValorDocumentoIdentidad: d.valorDocumentoIdentidad,
      FechaNacimiento: d.fechaNacimiento,
      Email: d.email,
      IdParentezco: d.idParentezco,
      Porcentaje: d.porcentaje,
      Activo: true,
    });
    return { ok: true };
  }
}

// Solo cambia nombre y parentesco.
// El porcentaje se cambia con actualizarPorcentajes (todos a la vez).
export async function actualizarBeneficiario(idBeneficiario, d) {
  if (!USAR_MOCK_BENEFICIARIOS) {
    return pedir('PUT', `/api/beneficiarios/${encodeURIComponent(idBeneficiario)}`, d);
  }
  if (USAR_MOCK_BENEFICIARIOS) {
    await esperar(200);
    const b = beneficiariosMock.find((x) => x.IdBeneficiario === idBeneficiario && x.Activo);
    if (!b) return fallo(50006);
    const codigo = validarNombreParentesco(d);
    if (codigo !== 0) return fallo(codigo);
    b.Nombre = d.nombre;
    b.IdParentezco = d.idParentezco;
    return { ok: true };
  }
}


// Recibe los porcentajes de TODOS los beneficiarios activos de la cuenta:
// [{ idBeneficiario, porcentaje }]. Deben sumar 100. O se guardan todos
// o no se guarda ninguno (en SQL Server será una transacción).
export async function actualizarPorcentajes(numeroCuenta, lista) {
  if (!USAR_MOCK_BENEFICIARIOS) {
    return pedir('PUT', `/api/cuentas/${encodeURIComponent(numeroCuenta)}/porcentajes`, { porcentajes: lista });
  }
  if (USAR_MOCK_BENEFICIARIOS) {
    await esperar(200);
    const activos = activosDe(numeroCuenta);
    // La lista debe traer exactamente a los beneficiarios activos, ni más ni menos.
    const mismosBeneficiarios =
      lista.length === activos.length &&
      activos.every((b) => lista.some((x) => x.idBeneficiario === b.IdBeneficiario));
    if (!mismosBeneficiarios) return fallo(50007);
    if (!lista.every((x) => porcentajeValido(x.porcentaje))) return fallo(50004);
    const suma = lista.reduce((total, x) => total + x.porcentaje, 0);
    if (suma !== 100) return fallo(50009);
    // Solo se llega aquí si TODO es válido: se aplican todos los cambios juntos.
    activos.forEach((b) => {
      b.Porcentaje = lista.find((x) => x.idBeneficiario === b.IdBeneficiario).porcentaje;
    });
    return { ok: true };
  }
}

// Real: sp_EliminarBeneficiario. Eliminación LÓGICA: el registro no se borra,
// se marca como inactivo (en la BD: FlagActivo = 0 y FechaDesactivacion).
export async function eliminarBeneficiario(idBeneficiario) {
  if (!USAR_MOCK_BENEFICIARIOS) {
    return pedir('DELETE', `/api/beneficiarios/${encodeURIComponent(idBeneficiario)}`);
  }
  if (USAR_MOCK_BENEFICIARIOS) {
    await esperar(200);
    const b = beneficiariosMock.find((x) => x.IdBeneficiario === idBeneficiario && x.Activo);
    if (!b) return fallo(50006);
    b.Activo = false;
    return { ok: true };
  }
}