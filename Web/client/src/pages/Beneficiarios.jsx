// BENEFICIARIOS Y CATÁLOGOS (solo con sesión iniciada)
//
//   GET    /api/catalogos/parentezcos              -> sp_ListarParentezcos
//   GET    /api/catalogos/tipos-documento          -> sp_ListarTiposDocumento
//   GET    /api/cuentas/:numero/beneficiarios      -> sp_ListarBeneficiarios
//   POST   /api/cuentas/:numero/beneficiarios      -> sp_AgregarBeneficiario
//   PUT    /api/cuentas/:numero/porcentajes        -> sp_ActualizarPorcentajes
//   PUT    /api/beneficiarios/:id                  -> sp_ActualizarBeneficiario
//   DELETE /api/beneficiarios/:id                  -> sp_EliminarBeneficiario

import { Router } from 'express';
import { sql } from '../db.js';
import { exigirSesion, responderError, fechaATexto } from './comunes.js';

// ---- Validaciones de forma (devuelven true si el dato tiene la forma correcta)
const esEntero = (v) => Number.isInteger(v);
const esTexto = (v, max) => typeof v === 'string' && v.length > 0 && v.length <= max;
const esSoloDigitos = (v, max) => esTexto(v, max) && /^[0-9]+$/.test(v);
const esFecha = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(v));
const esNumeroCuenta = (v) => typeof v === 'string' && /^[0-9]{1,16}$/.test(v);

// Id de beneficiario que llega en la URL: entero positivo.
function idDeUrl(texto) {
  return /^[0-9]{1,9}$/.test(texto) ? Number(texto) : null;
}

export function crearRutasBeneficiarios(ejecutarSP) {
  const router = Router();
  router.use(exigirSesion);

  // ---------------------------------------------------------------- catálogos
  // Alimentan los desplegables del formulario. Devuelven [{ Id, Nombre }].
  router.get('/catalogos/parentezcos', async (req, res, next) => {
    try {
      const { codigo, recordsets } = await ejecutarSP('dbo.sp_ListarParentezcos', {});
      if (codigo !== 0) return responderError(res, codigo);
      res.json({ ok: true, datos: recordsets[0] });
    } catch (error) {
      next(error);
    }
  });

  router.get('/catalogos/tipos-documento', async (req, res, next) => {
    try {
      const { codigo, recordsets } = await ejecutarSP('dbo.sp_ListarTiposDocumento', {});
      if (codigo !== 0) return responderError(res, codigo);
      res.json({ ok: true, datos: recordsets[0] });
    } catch (error) {
      next(error);
    }
  });

  // ------------------------------------------------------------------- listar
  // El SP devuelve DOS consultas: 1) los beneficiarios activos y 2) una fila
  // con la suma de porcentajes y la cantidad (la web la usa para la alerta).
  router.get('/cuentas/:numero/beneficiarios', async (req, res, next) => {
    try {
      if (!esNumeroCuenta(req.params.numero)) return responderError(res, 50002);

      const { codigo, recordsets } = await ejecutarSP('dbo.sp_ListarBeneficiarios', {
        inIdUsuario: [sql.Int, req.session.idUsuario],
        inNumeroCuenta: [sql.VarChar(16), req.params.numero],
      });
      if (codigo !== 0) return responderError(res, codigo);

      const beneficiarios = recordsets[0].map((b) => ({
        ...b,
        FechaNacimiento: fechaATexto(b.FechaNacimiento),
      }));
      // Si no hubiera fila de resumen, se calcula: la suma de 0 beneficiarios es 0.
      const resumen = recordsets[1]?.[0] ?? { SumaPorcentajes: 0, CantidadBeneficiarios: 0 };
      res.json({ ok: true, beneficiarios, resumen });
    } catch (error) {
      next(error);
    }
  });

  // ------------------------------------------------------------------ agregar
  router.post('/cuentas/:numero/beneficiarios', async (req, res, next) => {
    try {
      const d = req.body ?? {};
      const formaValida =
        esNumeroCuenta(req.params.numero) &&
        esEntero(d.idTipoDocuIdentidad) &&
        esSoloDigitos(d.valorDocumentoIdentidad, 32) &&
        esTexto(d.nombre, 64) &&
        esFecha(d.fechaNacimiento) &&
        esTexto(d.email, 128) &&
        esSoloDigitos(d.telefono1, 16) &&
        esSoloDigitos(d.telefono2, 16) &&
        esEntero(d.idParentezco) &&
        esEntero(d.porcentaje);
      if (!formaValida) return responderError(res, 50007);

      const { codigo } = await ejecutarSP('dbo.sp_AgregarBeneficiario', {
        inIdUsuario: [sql.Int, req.session.idUsuario],
        inNumeroCuenta: [sql.VarChar(16), req.params.numero],
        inIdTipoDocuIdentidad: [sql.Int, d.idTipoDocuIdentidad],
        inValorDocumentoIdentidad: [sql.VarChar(32), d.valorDocumentoIdentidad],
        inNombre: [sql.VarChar(64), d.nombre],
        inFechaNacimiento: [sql.Date, d.fechaNacimiento],
        inEmail: [sql.VarChar(128), d.email],
        inTelefono1: [sql.VarChar(16), d.telefono1],
        inTelefono2: [sql.VarChar(16), d.telefono2],
        inIdParentezco: [sql.Int, d.idParentezco],
        inPorcentaje: [sql.Int, d.porcentaje],
      });
      if (codigo !== 0) return responderError(res, codigo);
      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  });

  // ------------------------------------------------- porcentajes (todos juntos)
  // Recibe { porcentajes: [{ idBeneficiario, porcentaje }, ...] } con TODOS los
  // beneficiarios activos de la cuenta. Al SP se le pasa como XML (un solo
  // parámetro), para que se guarden todos o ninguno en una sola transacción.
  router.put('/cuentas/:numero/porcentajes', async (req, res, next) => {
    try {
      const lista = req.body?.porcentajes;
      const formaValida =
        esNumeroCuenta(req.params.numero) &&
        Array.isArray(lista) &&
        lista.length >= 1 &&
        lista.length <= 3 &&
        lista.every((x) => esEntero(x?.idBeneficiario) && esEntero(x?.porcentaje));
      if (!formaValida) return responderError(res, 50007);

      // El XML se arma SOLO con números enteros ya validados, así que no puede
      // contener texto del usuario ni caracteres especiales de XML.
      const xml =
        '<p>' + lista.map((x) => `<b id="${x.idBeneficiario}" pct="${x.porcentaje}"/>`).join('') + '</p>';

      const { codigo } = await ejecutarSP('dbo.sp_ActualizarPorcentajes', {
        inIdUsuario: [sql.Int, req.session.idUsuario],
        inNumeroCuenta: [sql.VarChar(16), req.params.numero],
        inXml: [sql.Xml, xml],
      });
      if (codigo !== 0) return responderError(res, codigo);
      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  });

  // ---------------------------------------------------- actualizar y eliminar
  // Solo cambia nombre y parentesco; el porcentaje se cambia con la ruta de arriba.
  router.put('/beneficiarios/:id', async (req, res, next) => {
    try {
      const id = idDeUrl(req.params.id);
      const d = req.body ?? {};
      if (id === null || !esTexto(d.nombre, 64) || !esEntero(d.idParentezco)) {
        return responderError(res, 50007);
      }
      const { codigo } = await ejecutarSP('dbo.sp_ActualizarBeneficiario', {
        inIdUsuario: [sql.Int, req.session.idUsuario],
        inIdBeneficiario: [sql.Int, id],
        inNombre: [sql.VarChar(64), d.nombre],
        inIdParentezco: [sql.Int, d.idParentezco],
      });
      if (codigo !== 0) return responderError(res, codigo);
      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  });

  router.delete('/beneficiarios/:id', async (req, res, next) => {
    try {
      const id = idDeUrl(req.params.id);
      if (id === null) return responderError(res, 50006);
      const { codigo } = await ejecutarSP('dbo.sp_EliminarBeneficiario', {
        inIdUsuario: [sql.Int, req.session.idUsuario],
        inIdBeneficiario: [sql.Int, id],
      });
      if (codigo !== 0) return responderError(res, codigo);
      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  });

  return router;
}