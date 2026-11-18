//  CONTROL DE LA SIMULACIÓN (solo lectura, con sesión iniciada)
//   GET /api/simulacion/control -> sp_ConsultarControlSimulacion
// Muestra lo que deja Simulacion_TP3.sql en dbo.CorridaSimulacion y
// dbo.ControlSimulacion: qué fechas están terminadas, cuál quedó a medias y
// desde dónde reanuda la siguiente corrida. No cambia nada en la base.

import { Router } from 'express';
import { exigirSesion, responderError, fechaATexto } from './Comunes.js';

// Las fechas con hora (DATETIME2) llegan como objetos Date. Se muestran como
// texto 'AAAA-MM-DD hh:mm:ss', con la misma hora que guardó SQL Server.
function fechaHoraATexto(valor) {
  return valor instanceof Date ? valor.toISOString().slice(0, 19).replace('T', ' ') : valor;
}

export function crearRutasSimulacion(ejecutarSP) {
  const router = Router();
  router.use(exigirSesion); // todas las rutas de este archivo exigen sesión

  router.get('/control', async (req, res, next) => {
    try {
      const { codigo, recordsets } = await ejecutarSP('dbo.sp_ConsultarControlSimulacion');
      if (codigo !== 0) return responderError(res, codigo);

      // El SP devuelve 3 consultas: resumen, corridas y fechas.
      const [filasResumen = [], filasCorridas = [], filasFechas = []] = recordsets;
      const r = filasResumen[0] ?? {};

      const resumen = {
        ...r,
        FechaInicioXml: fechaATexto(r.FechaInicioXml),
        FechaFinXml: fechaATexto(r.FechaFinXml),
        UltimaFechaTerminada: fechaATexto(r.UltimaFechaTerminada),
        ProximaFechaPendiente: fechaATexto(r.ProximaFechaPendiente),
      };
      const corridas = filasCorridas.map((c) => ({
        ...c,
        FechaHoraInicio: fechaHoraATexto(c.FechaHoraInicio),
        FechaHoraFin: fechaHoraATexto(c.FechaHoraFin),
        FechaDesde: fechaATexto(c.FechaDesde),
        FechaHasta: fechaATexto(c.FechaHasta),
      }));
      const fechas = filasFechas.map((f) => ({
        ...f,
        FechaOperacion: fechaATexto(f.FechaOperacion),
        FechaHoraInicio: fechaHoraATexto(f.FechaHoraInicio),
        FechaHoraFin: fechaHoraATexto(f.FechaHoraFin),
      }));

      res.json({ ok: true, resumen, corridas, fechas });
    } catch (error) {
      next(error);
    }
  });

  return router;
}