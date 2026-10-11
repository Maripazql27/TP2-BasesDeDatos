
// app.js — arma el servidor Express (sesión + rutas + manejo de errores)
import express from 'express';
import session from 'express-session';
import { crearRutasSesion } from './rutas/sesion.js';
import { crearRutasCuentas } from './rutas/cuentas.js';

export function crearApp(ejecutarSP, { secreto, produccion = false } = {}) {
  const app = express();

  // Convierte el cuerpo JSON de las peticiones en un objeto (req.body).
  // El límite pequeño evita que alguien mande cuerpos enormes.
  app.use(express.json({ limit: '10kb' }));

  // SESIÓN. Cuando el login sale bien, el servidor guarda el IdUsuario EN LA
  // MEMORIA DEL SERVIDOR y le da al navegador solo una cookie con un
  // identificador al azar. Así el navegador nunca puede "decir" quién es: el
  // IdUsuario que se usa en los SP siempre sale de la sesión (req.session),
  // jamás de lo que mande el navegador.
  //   httpOnly: el JavaScript de la página no puede leer la cookie.
  //   sameSite 'lax': la cookie no viaja en peticiones enviadas desde otros sitios.
  //   secure: solo se activa con HTTPS (en producción); en local no hay HTTPS.
  // La sesión se guarda en memoria: si se reinicia el servidor, hay que volver
  // a iniciar sesión (suficiente para el curso; un sistema real usaría un almacén persistente).
  app.use(
    session({
      secret: secreto,
      resave: false,              // no re-guarda la sesión si no cambió
      saveUninitialized: false,   // no crea cookie hasta que haya login
      name: 'tp2.sid',
      cookie: {
        httpOnly: true,
        sameSite: 'lax',
        secure: produccion,
        maxAge: 30 * 60 * 1000,   // 30 minutos
      },
    })
  );

  // Rutas. Todas viven bajo /api para distinguirlas de la web.
  app.use('/api', crearRutasSesion(ejecutarSP));
  app.use('/api/cuentas', crearRutasCuentas(ejecutarSP));

  
  app.use('/api', (req, res) =>
    res.status(501).json({ ok: false, codigo: 50000, mensaje: 'Esta función aún no está disponible.' })
  );

  // Último recurso: cualquier error no previsto (por ejemplo, SQL Server caído)
  // se registra en la consola del servidor y al navegador solo se le dice un
  // mensaje genérico. Así no se filtran detalles internos (nombres de tablas y otras cosas.).
  app.use((error, req, res, next) => {
    console.error('Error no controlado:', error.message);
    res.status(500).json({ ok: false, codigo: 50000, mensaje: 'Ocurrió un error inesperado.' });
  });

  return app;
}