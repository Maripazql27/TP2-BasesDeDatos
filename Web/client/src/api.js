
// APA DE ACCESO A DATOS DE LA WEB
// ESTADO DE LA CONEXIÓN
//     iniciarSesion          -> POST /api/login   -> sp_IniciarSesion
//     cerrarSesion           -> POST /api/logout  -> sp_CerrarSesion
//     obtenerSesion          -> GET  /api/sesion  (¿quién tiene sesión?)
//     listarCuentas          -> GET  /api/cuentas -> sp_ListarCuentasUsuario
//     consultarEstados       -> GET  /api/cuentas/:numero/estados
//                                                 -> sp_ConsultarEstadosCuenta


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

// ---------------------------------------------------------------- BENEFICIARIOS
// Todas llaman al servidor, que llama al SP correspondiente (no hay datos de prueba aquí).
//   listarParentezcos      -> GET    /api/catalogos/parentezcos        -> sp_ListarParentezcos
//   listarTiposDocumento   -> GET    /api/catalogos/tipos-documento    -> sp_ListarTiposDocumento
//   listarBeneficiarios    -> GET    /api/cuentas/:n/beneficiarios     -> sp_ListarBeneficiarios
//   agregarBeneficiario    -> POST   /api/cuentas/:n/beneficiarios     -> sp_AgregarBeneficiario
//   actualizarBeneficiario -> PUT    /api/beneficiarios/:id            -> sp_ActualizarBeneficiario
//   actualizarPorcentajes  -> PUT    /api/cuentas/:n/porcentajes       -> sp_ActualizarBeneficiario (uno por beneficiario)
//   eliminarBeneficiario   -> DELETE /api/beneficiarios/:id            -> sp_EliminarBeneficiario

// Desplegable de parentesco: [{ Id, Nombre }].
export function listarParentezcos() {
  return pedir('GET', '/api/catalogos/parentezcos');
}

// Desplegable de tipo de documento: [{ Id, Nombre }].
export function listarTiposDocumento() {
  return pedir('GET', '/api/catalogos/tipos-documento');
}

// Devuelve { ok, beneficiarios, resumen }: 1) la lista de beneficiarios activos y
// 2) una fila con SumaPorcentajes y CantidadBeneficiarios (para la alerta).
export function listarBeneficiarios(numeroCuenta) {
  return pedir('GET', `/api/cuentas/${encodeURIComponent(numeroCuenta)}/beneficiarios`);
}

// d = { idTipoDocuIdentidad, valorDocumentoIdentidad, nombre, fechaNacimiento, email,
//       telefono1, telefono2, idParentezco, porcentaje }
export function agregarBeneficiario(numeroCuenta, d) {
  return pedir('POST', `/api/cuentas/${encodeURIComponent(numeroCuenta)}/beneficiarios`, d);
}

// d = { nombre, idParentezco, porcentaje }. El SP exige los tres; el formulario manda el
// porcentaje que el beneficiario ya tiene, así que aquí cambian nombre y parentesco.
export function actualizarBeneficiario(idBeneficiario, d) {
  return pedir('PUT', `/api/beneficiarios/${encodeURIComponent(idBeneficiario)}`, d);
}

// lista = [{ idBeneficiario, porcentaje }] con TODOS los beneficiarios activos de la
// cuenta. La suma no puede pasar de 100; si queda menor, la pantalla muestra la alerta.
export function actualizarPorcentajes(numeroCuenta, lista) {
  return pedir('PUT', `/api/cuentas/${encodeURIComponent(numeroCuenta)}/porcentajes`, { porcentajes: lista });
}

// Eliminación LÓGICA: el registro no se borra, queda inactivo (FlagActivo = 0).
export function eliminarBeneficiario(idBeneficiario) {
  return pedir('DELETE', `/api/beneficiarios/${encodeURIComponent(idBeneficiario)}`);
}