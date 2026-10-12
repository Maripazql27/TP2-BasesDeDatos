
// =============================================================================
// rutas/comunes.js — piezas compartidas por las rutas
// =============================================================================

// Código de error del grupo -> mensaje que ve el usuario (igual que MENSAJES en api.js).
export const MENSAJES = {
  50000: 'Ocurrió un error inesperado.',
  50001: 'Usuario o clave incorrectos.',
  50002: 'No tiene acceso a esta cuenta.',
  50003: 'La cuenta ya tiene 3 beneficiarios activos.',
  50004: 'El porcentaje debe ser un entero entre 1 y 100.',
  50005: 'Esa persona ya es beneficiaria activa de esta cuenta.',
  50006: 'El beneficiario no existe o ya está inactivo.',
  50007: 'Hay datos inválidos. Revise el formulario.',
  50008: 'El parentesco o el tipo de documento no existe.',
  50009: 'La suma de los porcentajes de los beneficiarios no puede superar 100.',
};


export function httpDeCodigo(codigo) {
  if (codigo === 0) return 200;
  if (codigo === 50001) return 401;
  if (codigo === 50002) return 403;
  if (codigo === 50003 || codigo === 50005) return 409;
  if (codigo === 50006) return 404;
  if ([50004, 50007, 50008, 50009].includes(codigo)) return 400;
  return 500;
}

// Respuesta de error estándar: { ok:false, codigo, mensaje }, con el HTTP que toca.
export function responderError(res, codigo) {
  res
    .status(httpDeCodigo(codigo))
    .json({ ok: false, codigo, mensaje: MENSAJES[codigo] ?? MENSAJES[50000] });
}

// Middleware: deja pasar solo si hay sesión iniciada. Si no, 401.
// Las rutas protegidas lo usan, y así NINGUNA llega al SP sin usuario en sesión.
export function exigirSesion(req, res, next) {
  if (!req.session.idUsuario) {
    return res.status(401).json({ ok: false, codigo: 50001, mensaje: 'Debe iniciar sesión.' });
  }
  next();
}

// Las fechas (DATE) llegan de SQL Server como objetos Date a medianoche UTC.
// La web las muestra tal cual, así que se convierten a texto 'AAAA-MM-DD'.
export function fechaATexto(valor) {
  return valor instanceof Date ? valor.toISOString().slice(0, 10) : valor;
}