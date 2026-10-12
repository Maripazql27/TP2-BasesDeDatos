
//  LOGIN Y LOGOUT
//   POST /api/login   -> sp_IniciarSesion
//   POST /api/logout  -> sp_CerrarSesion
//   GET  /api/sesion  -> dice quién tiene sesión (para que la web no pierda la
//                        sesión al recargar la página). No llama a ningún SP.

import { Router } from 'express';
import { sql } from '../Db.js';
import { responderError, exigirSesion } from './Comunes.js';

export function crearRutasSesion(ejecutarSP) {
  const router = Router();

  router.post('/login', async (req, res, next) => {
    try {
      const { nombreUsuario, clave } = req.body ?? {};

      // Validación de FORMA (no de negocio): deben ser textos y no excederse
      // del largo de las columnas. Si no, ni se molesta a la base de datos.
      const textoValido = (t, max) => typeof t === 'string' && t.length > 0 && t.length <= max;
      if (!textoValido(nombreUsuario, 64) || !textoValido(clave, 128)) {
        return responderError(res, 50001);
      }

      // La IP viene de la conexión (req.ip), no de lo que mande el navegador.
      // Se corta a 45 caracteres, el largo de la columna.
      const ip = String(req.ip ?? '').slice(0, 45);

      // Los parámetros viajan tipados al SP (nunca se pegan dentro de un texto SQL), por eso un usuario como  ' OR 1=1 --  no puede inyectar SQL.
      const { codigo, recordsets } = await ejecutarSP('dbo.sp_IniciarSesion', {
        inNombreUsuario: [sql.VarChar(64), nombreUsuario],
        inClave: [sql.VarChar(128), clave],
        inIP: [sql.VarChar(45), ip],
      });
      if (codigo !== 0) return responderError(res, codigo);

      const fila = recordsets[0][0];
      const usuario = {
        idUsuario: fila.IdUsuario,
        nombreUsuario,
        esAdministrador: Boolean(fila.EsAdministrador),
      };

      // regenerate() crea una sesión NUEVA al hacer login (con otro identificador),
      // para que nadie pueda "pre-fabricar" un identificador de sesión y luego
      // aprovecharlo cuando la víctima inicie sesión (fijación de sesión).
      req.session.regenerate((error) => {
        if (error) return next(error);
        req.session.idUsuario = usuario.idUsuario;
        req.session.nombreUsuario = usuario.nombreUsuario;
        req.session.esAdministrador = usuario.esAdministrador;
        res.json({ ok: true, usuario });
      });
    } catch (error) {
      next(error);
    }
  });

  router.post('/logout', exigirSesion, async (req, res, next) => {
    try {
      // El Id sale de la sesión, no del cuerpo de la petición.
      const { codigo } = await ejecutarSP('dbo.sp_CerrarSesion', {
        inIdUsuario: [sql.Int, req.session.idUsuario],
      });
      // Haya salido bien o no la bitácora, la sesión se destruye: el usuario
      // pidió salir y debe quedar fuera.
      req.session.destroy((error) => {
        if (error) return next(error);
        res.clearCookie('tp2.sid');
        if (codigo !== 0) return responderError(res, codigo);
        res.json({ ok: true });
      });
    } catch (error) {
      next(error);
    }
  });

  router.get('/sesion', (req, res) => {
    if (!req.session.idUsuario) {
      return res.status(401).json({ ok: false, codigo: 50001, mensaje: 'Debe iniciar sesión.' });
    }
    res.json({
      ok: true,
      usuario: {
        idUsuario: req.session.idUsuario,
        nombreUsuario: req.session.nombreUsuario,
        esAdministrador: req.session.esAdministrador,
      },
    });
  });

  return router;
}