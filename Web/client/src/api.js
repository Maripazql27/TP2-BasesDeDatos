const USAR_MOCK = true; // permite las pruebas con datos simulados

const esperar = (ms) => new Promise((resolver) => setTimeout(resolver, ms));

export async function iniciarSesion(nombreUsuario, clave) {
  if (USAR_MOCK) {
    await esperar(300);
    if (nombreUsuario === 'Nacho' && clave === '123') { //cuenta alambrada de prueba
      return {
        ok: true,
        usuario: { idUsuario: 1, nombreUsuario, esAdministrador: false },
      };
    }
    return { ok: false, codigo: 50001, mensaje: 'Usuario o clave incorrectos.' };
  }
}


// Las columnas deberian llevar el mismo nombre que devolverán los SP
// (sp_ListarCuentasUsuario y sp_ConsultarEstadosCuenta).
export async function listarCuentas() {
  if (USAR_MOCK) {
    await esperar(200);
    return {
      ok: true,
      datos: [
        { IdCuenta: 1, NumeroCuenta: '11000001', Saldo: 1000000, NombreTipoCuenta: 'Asalariado' },
        { IdCuenta: 2, NumeroCuenta: '11000002', Saldo: 250000, NombreTipoCuenta: 'Profesional' },
      ],
    };
  }
}

export async function consultarEstados(numeroCuenta) {
  if (USAR_MOCK) {
    await esperar(200);
    // Simula una cuenta con 12 estados: el SP real solo devolverá los 8 más recientes.
    const estados = [];
    for (let i = 0; i < 12; i++) {
      const mes = String(i + 1).padStart(2, '0');
      estados.push({
        IdEstadoCuenta: i + 1,
        FechaInicio: `2026-${mes}-13`,
        FechaFin: `2026-${mes}-27`,
        FechaEmision: `2026-${mes}-28`,
        SaldoInicial: 1000000 + i * 10000,
        SaldoFinal: 1010000 + i * 10000,
        SaldoMinimo: 900000,
        InteresesAcumulados: 5000 + i * 100,
        CantRetiros: i % 4,
        CantDepositos: (i % 3) + 1,
        CantSinpeEntrantes: i % 2,
        CantSinpeSalientes: (i + 1) % 2,
      });
    }
    estados.sort((a, b) => b.FechaFin.localeCompare(a.FechaFin));
    return { ok: true, datos: estados.slice(0, 8) };
  }
}


// ---------------------------------------------------------------
// Beneficiarios (simulado). Los códigos de error son los del grupo.
// 50009 es un código NUEVO propuesto (pendiente de acordar con el grupo).
// ---------------------------------------------------------------
const MENSAJES = {
  50000: 'Ocurrió un error inesperado.',
  50002: 'No tiene acceso a esta cuenta.',
  50003: 'La cuenta ya tiene 3 beneficiarios activos.',
  50004: 'El porcentaje debe ser un entero entre 0 y 100.',
  50005: 'Esa persona ya es beneficiaria activa de esta cuenta.',
  50006: 'El beneficiario no existe o ya está inactivo.',
  50007: 'Hay datos inválidos. Revise el formulario.',
  50008: 'El parentesco o el tipo de documento no existe.',
  50009: 'Los porcentajes de todos los beneficiarios deben sumar exactamente 100.',
};

const fallo = (codigo) => ({ ok: false, codigo, mensaje: MENSAJES[codigo] });

const PARENTEZCOS = [
  { Id: 1, Nombre: 'Padre' },
  { Id: 2, Nombre: 'Madre' },
  { Id: 3, Nombre: 'Hijo' },
  { Id: 4, Nombre: 'Hija' },
  { Id: 5, Nombre: 'Hermano' },
  { Id: 6, Nombre: 'Hermana' },
  { Id: 7, Nombre: 'amigo' },
  { Id: 8, Nombre: 'amiga' },
];

const TIPOS_DOCUMENTO = [
  { Id: 1, Nombre: 'Cedula Nacional' },
  { Id: 2, Nombre: 'Cedula Residente' },
  { Id: 3, Nombre: 'Pasaporte' },
  { Id: 4, Nombre: 'Cedula Juridica' },
  { Id: 5, Nombre: 'Permiso de Trabajo' },
  { Id: 6, Nombre: 'Cedula Extranjera' },
];

// Datos falsos. Activo = false significa desactivado (eliminación lógica).
let siguienteIdBeneficiario = 4;
const beneficiariosMock = [
  { IdBeneficiario: 1, NumeroCuenta: '11000001', Nombre: 'Ana Mora Solano',
    ValorDocumentoIdentidad: '100000001', FechaNacimiento: '1990-05-10',
    Email: 'ana@correo.com', IdParentezco: 6, Porcentaje: 60, Activo: true },
  { IdBeneficiario: 2, NumeroCuenta: '11000001', Nombre: 'Luis Mora Solano',
    ValorDocumentoIdentidad: '100000002', FechaNacimiento: '1992-08-21',
    Email: 'luis@correo.com', IdParentezco: 5, Porcentaje: 40, Activo: true },
  { IdBeneficiario: 3, NumeroCuenta: '11000002', Nombre: 'Rosa Vega Rojas',
    ValorDocumentoIdentidad: '100000003', FechaNacimiento: '1985-01-02',
    Email: 'rosa@correo.com', IdParentezco: 2, Porcentaje: 50, Activo: true },
];

const activosDe = (numeroCuenta) =>
  beneficiariosMock.filter((b) => b.NumeroCuenta === numeroCuenta && b.Activo);

// Validaciones que en la versión real hará el SP.
const porcentajeValido = (p) => Number.isInteger(p) && p >= 0 && p <= 100;

function validarNombreParentesco(d) {
  if (!d.nombre || d.nombre.length > 64) return 50007;
  if (!PARENTEZCOS.some((p) => p.Id === d.idParentezco)) return 50008;
  return 0;
}

function validarAlta(d) {
  const soloDigitos = (t, max) => /^[0-9]+$/.test(t) && t.length <= max;
  if (!soloDigitos(d.valorDocumentoIdentidad, 32)) return 50007;
  if (!soloDigitos(d.telefono1, 16) || !soloDigitos(d.telefono2, 16)) return 50007;
  if (!d.fechaNacimiento || !d.email.includes('@')) return 50007;
  if (!TIPOS_DOCUMENTO.some((t) => t.Id === d.idTipoDocuIdentidad)) return 50008;
  return 0;
}

export async function listarParentezcos() {
  if (USAR_MOCK) {
    await esperar(100);
    return { ok: true, datos: PARENTEZCOS };
  }
}

export async function listarTiposDocumento() {
  if (USAR_MOCK) {
    await esperar(100);
    return { ok: true, datos: TIPOS_DOCUMENTO };
  }
}

// Devuelve lo mismo que los dos resultsets de sp_ListarBeneficiarios.
export async function listarBeneficiarios(numeroCuenta) {
  if (USAR_MOCK) {
    await esperar(200);
    const activos = activosDe(numeroCuenta);
    const beneficiarios = activos.map((b) => ({
      IdBeneficiario: b.IdBeneficiario,
      Nombre: b.Nombre,
      ValorDocumentoIdentidad: b.ValorDocumentoIdentidad,
      FechaNacimiento: b.FechaNacimiento,
      Email: b.Email,
      IdParentezco: b.IdParentezco,
      NombreParentezco: PARENTEZCOS.find((p) => p.Id === b.IdParentezco).Nombre,
      Porcentaje: b.Porcentaje,
    }));
    const resumen = {
      SumaPorcentajes: activos.reduce((suma, b) => suma + b.Porcentaje, 0),
      CantidadBeneficiarios: activos.length,
    };
    return { ok: true, beneficiarios, resumen };
  }
}

export async function agregarBeneficiario(numeroCuenta, d) {
  if (USAR_MOCK) {
    await esperar(200);
    let codigo = validarNombreParentesco(d);
    if (codigo === 0 && !porcentajeValido(d.porcentaje)) codigo = 50004;
    if (codigo === 0) codigo = validarAlta(d);
    if (codigo === 0 && activosDe(numeroCuenta).length >= 3) codigo = 50003;
    if (codigo === 0 && activosDe(numeroCuenta).some(
      (b) => b.ValorDocumentoIdentidad === d.valorDocumentoIdentidad)) codigo = 50005;
    if (codigo !== 0) return fallo(codigo);
    beneficiariosMock.push({
      IdBeneficiario: siguienteIdBeneficiario++,
      NumeroCuenta: numeroCuenta,
      Nombre: d.nombre,
      ValorDocumentoIdentidad: d.valorDocumentoIdentidad,
      FechaNacimiento: d.fechaNacimiento,
      Email: d.email,
      IdParentezco: d.idParentezco,
      Porcentaje: d.porcentaje,
      Activo: true,
    });
    return { ok: true };
  }
}

// Solo cambia nombre y parentesco. El porcentaje se cambia con
// actualizarPorcentajes (todos a la vez).
export async function actualizarBeneficiario(idBeneficiario, d) {
  if (USAR_MOCK) {
    await esperar(200);
    const b = beneficiariosMock.find((x) => x.IdBeneficiario === idBeneficiario && x.Activo);
    if (!b) return fallo(50006);
    const codigo = validarNombreParentesco(d);
    if (codigo !== 0) return fallo(codigo);
    b.Nombre = d.nombre;
    b.IdParentezco = d.idParentezco;
    return { ok: true };
  }
}

// Recibe los porcentajes de TODOS los beneficiarios activos de la cuenta:
// [{ idBeneficiario, porcentaje }]. Deben sumar 100. O se guardan todos
// o no se guarda ninguno (en SQL Server será una transacción).
export async function actualizarPorcentajes(numeroCuenta, lista) {
  if (USAR_MOCK) {
    await esperar(200);
    const activos = activosDe(numeroCuenta);
    const mismosBeneficiarios =
      lista.length === activos.length &&
      activos.every((b) => lista.some((x) => x.idBeneficiario === b.IdBeneficiario));
    if (!mismosBeneficiarios) return fallo(50007);
    if (!lista.every((x) => porcentajeValido(x.porcentaje))) return fallo(50004);
    const suma = lista.reduce((total, x) => total + x.porcentaje, 0);
    if (suma !== 100) return fallo(50009);
    activos.forEach((b) => {
      b.Porcentaje = lista.find((x) => x.idBeneficiario === b.IdBeneficiario).porcentaje;
    });
    return { ok: true };
  }
}

// Eliminación lógica: no se borra, se marca como inactivo.
export async function eliminarBeneficiario(idBeneficiario) {
  if (USAR_MOCK) {
    await esperar(200);
    const b = beneficiariosMock.find((x) => x.IdBeneficiario === idBeneficiario && x.Activo);
    if (!b) return fallo(50006);
    b.Activo = false;
    return { ok: true };
  }
}