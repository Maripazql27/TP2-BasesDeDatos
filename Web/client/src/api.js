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