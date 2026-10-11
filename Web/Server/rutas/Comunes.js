
// Piezas compartidas por las rutas

// Código de error del grupo -> mensaje que ve el usuario 
export const MENSAJES = {
  50000: 'Ocurrió un error inesperado.',
  50001: 'Usuario o clave incorrectos.',
  50002: 'No tiene acceso a esta cuenta.',
};

// Código del SP -> código HTTP.
//   0     -> 200 (todo bien)
//   50001 -> 401 (no autenticado: credenciales malas)
//   50002 -> 403 (autenticado pero sin permiso / no existe)
//   otro  -> 500 (no debería pasar: el SP devolvió algo no previsto)
export function httpDeCodigo(codigo) {
  if (codigo === 0) return 200;
  if (codigo === 50001) return 401;
  if (codigo === 50002) return 403;
  return 500;
}

// Respuesta de error estándar: { ok:false, codigo, mensaje }, con el HTTP que toca.
export function responderError(res, codigo) {
  res
    .status(httpDeCodigo(codigo))
    .json({ ok: false, codigo, mensaje: MENSAJES[codigo] ?? MENSAJES[50000] });
}

// deja pasar solo si hay sesión iniciada. Si no, 401.
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