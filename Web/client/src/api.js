const USAR_MOCK = true;

const esperar = (ms) => new Promise((resolver) => setTimeout(resolver, ms));

export async function iniciarSesion(nombreUsuario, clave) {
  if (USAR_MOCK) {
    await esperar(300);
    if (nombreUsuario === 'jaguero' && clave === 'LaFacil') { //cuenta alambrada de prueba
      return {
        ok: true,
        usuario: { idUsuario: 1, nombreUsuario, esAdministrador: false },
      };
    }
    return { ok: false, codigo: 50001, mensaje: 'Usuario o clave incorrectos.' };
  }
}