//  CUENTAS Y ESTADOS DE CUENTA (solo con sesión iniciada)
//   GET /api/cuentas                    -> sp_ListarCuentasUsuario
//   GET /api/cuentas/:numero/estados    -> sp_ConsultarEstadosCuenta
//   GET /api/cuentas/:numero/estados/:idEstado/movimientos
//                                       -> sp_ConsultarMovimientosEstadoCuenta
// La autorización (quién puede ver qué cuenta) la decide el SP; aquí solo se
// le pasa el IdUsuario de la sesión y se traduce su código.

import { Router } from 'express';
import { sql } from '../Db.js';
import { exigirSesion, responderError, fechaATexto } from './Comunes.js';

export function crearRutasCuentas(ejecutarSP) {
  const router = Router();
  router.use(exigirSesion); // todas las rutas de este archivo exigen sesión

  router.get('/', async (req, res, next) => {
    try {
      const { codigo, recordsets } = await ejecutarSP('dbo.sp_ListarCuentasUsuario', {
        inIdUsuario: [sql.Int, req.session.idUsuario],
      });
      if (codigo !== 0) return responderError(res, codigo);
      res.json({ ok: true, datos: recordsets[0] });
    } catch (error) {
      next(error);
    }
  });

  router.get('/:numero/estados', async (req, res, next) => {
    try {
      const numero = req.params.numero;
      // Forma válida de un número de cuenta: solo dígitos, hasta 16.
      // Un valor raro recibe el mismo 50002 que una cuenta ajena.
      if (!/^[0-9]{1,16}$/.test(numero)) return responderError(res, 50002);

      const { codigo, recordsets } = await ejecutarSP('dbo.sp_ConsultarEstadosCuenta', {
        inIdUsuario: [sql.Int, req.session.idUsuario],
        inNumeroCuenta: [sql.VarChar(16), numero],
      });
      if (codigo !== 0) return responderError(res, codigo);

      const datos = recordsets[0].map((e) => ({
        ...e,
        FechaInicio: fechaATexto(e.FechaInicio),
        FechaFin: fechaATexto(e.FechaFin),
        FechaEmision: fechaATexto(e.FechaEmision),
      }));
      res.json({ ok: true, datos });
    } catch (error) {
      next(error);
    }
  });

  // Movimientos de UN estado de cuenta (TP3). El SP valida que el usuario pueda
  // ver la cuenta y que el estado pertenezca a esa cuenta; si no, devuelve 50002.
  router.get('/:numero/estados/:idEstado/movimientos', async (req, res, next) => {
    try {
      const { numero, idEstado } = req.params;
      if (!/^[0-9]{1,16}$/.test(numero)) return responderError(res, 50002);
      if (!/^[0-9]{1,9}$/.test(idEstado)) return responderError(res, 50002);

      const { codigo, recordsets } = await ejecutarSP('dbo.sp_ConsultarMovimientosEstadoCuenta', {
        inIdUsuario: [sql.Int, req.session.idUsuario],
        inNumeroCuenta: [sql.VarChar(16), numero],
        inIdEstadoCuenta: [sql.Int, Number(idEstado)],
      });
      if (codigo !== 0) return responderError(res, codigo);

      const datos = recordsets[0].map((m) => ({
        ...m,
        FechaMovimiento: fechaATexto(m.FechaMovimiento),
      }));
      res.json({ ok: true, datos });
    } catch (error) {
      next(error);
    }
  });

  return router;
}