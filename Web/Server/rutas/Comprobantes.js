//  COMPROBANTES POR CORREO (solo el administrador)
//   GET  /api/comprobantes         -> sp_ConsultarComprobantes (todos)
//   POST /api/comprobantes/enviar  -> sp_ConsultarComprobantes (pendientes),
//                                     envía cada correo y registra el
//                                     resultado con sp_RegistrarEnvioComprobante
// sp_AplicarMovimiento deja cada comprobante listo dentro de la transacción
// del movimiento. Aquí solo se envía, DESPUÉS de esa transacción (ver
// Correo.js). Un comprobante enviado queda marcado y no se vuelve a enviar.
// Código propio de esta ruta: 50603 = ya hay un envío en curso.

import { Router } from 'express';
import { sql } from '../Db.js';
import { exigirSesion, exigirAdmin, responderError, fechaATexto } from './Comunes.js';

// Las fechas con hora (DATETIME2) llegan como objetos Date. Se muestran como
// texto 'AAAA-MM-DD hh:mm:ss', con la misma hora que guardó SQL Server.
function fechaHoraATexto(valor) {
  return valor instanceof Date ? valor.toISOString().slice(0, 19).replace('T', ' ') : valor;
}

function conFechasEnTexto(comprobante) {
  return {
    ...comprobante,
    FechaOperacion: fechaATexto(comprobante.FechaOperacion),
    FechaHoraCreacion: fechaHoraATexto(comprobante.FechaHoraCreacion),
    FechaHoraEnvio: fechaHoraATexto(comprobante.FechaHoraEnvio),
  };
}

const RESUMEN_VACIO = { CantGenerados: 0, CantEnviados: 0, CantPendientes: 0, CantConError: 0 };

export function crearRutasComprobantes(ejecutarSP, enviadorCorreo) {
  const router = Router();
  // Todas las rutas de este archivo exigen sesión Y que sea el administrador.
  router.use(exigirSesion, exigirAdmin);

  // Un solo envío a la vez: si se presiona el botón otra vez mientras se
  // envía, se responde 409 en lugar de mandar de nuevo los mismos correos.
  let envioEnCurso = false;

  function consultar(soloPendientes) {
    return ejecutarSP('dbo.sp_ConsultarComprobantes', {
      inFlagSoloPendientes: [sql.Bit, soloPendientes],
    });
  }

  router.get('/', async (req, res, next) => {
    try {
      const { codigo, recordsets } = await consultar(false);
      if (codigo !== 0) return responderError(res, codigo);

      const [filasResumen = [], filas = []] = recordsets;
      res.json({
        ok: true,
        resumen: filasResumen[0] ?? RESUMEN_VACIO,
        comprobantes: filas.map(conFechasEnTexto),
        envio: { modo: enviadorCorreo.modo, descripcion: enviadorCorreo.descripcion },
      });
    } catch (error) {
      next(error);
    }
  });

  router.post('/enviar', async (req, res, next) => {
    if (envioEnCurso) {
      return res.status(409).json({
        ok: false,
        codigo: 50603,
        mensaje: 'Ya hay un envío de comprobantes en curso. Espere a que termine.',
      });
    }
    envioEnCurso = true;
    try {
      const { codigo, recordsets } = await consultar(true);
      if (codigo !== 0) return responderError(res, codigo);

      // Del más antiguo al más reciente: en el orden en que se generaron.
      const pendientes = [...(recordsets[1] ?? [])].sort(
        (a, b) => a.IdComprobante - b.IdComprobante
      );

      let enviados = 0;
      let fallidos = 0;
      let sinRegistrar = 0;
      for (const comprobante of pendientes) {
        let flagEnviado = true;
        let mensajeError = null;
        try {
          await enviadorCorreo.enviar(comprobante);
        } catch (error) {
          flagEnviado = false;
          mensajeError = String(error?.message ?? error).slice(0, 400);
          console.error(`Comprobante ${comprobante.IdComprobante}: no se pudo enviar:`, mensajeError);
        }

        // Se registra si salió o no. Si el correo salió pero la base falla
        // justo aquí, el comprobante sigue pendiente y se enviaría otra vez:
        // es preferible un correo repetido a un comprobante que nunca llega.
        const registro = await ejecutarSP('dbo.sp_RegistrarEnvioComprobante', {
          inIdComprobante: [sql.Int, comprobante.IdComprobante],
          inFlagEnviado: [sql.Bit, flagEnviado],
          inMensajeError: [sql.NVarChar(400), mensajeError],
        });
        if (registro.codigo !== 0) {
          sinRegistrar += 1;
          console.error(
            `Comprobante ${comprobante.IdComprobante}: sp_RegistrarEnvioComprobante devolvió ${registro.codigo}`
          );
        }

        if (flagEnviado) enviados += 1;
        else fallidos += 1;
      }

      res.json({ ok: true, total: pendientes.length, enviados, fallidos, sinRegistrar });
    } catch (error) {
      next(error);
    } finally {
      envioEnCurso = false;
    }
  });

  return router;
}
