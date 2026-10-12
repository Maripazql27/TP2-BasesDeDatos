import 'dotenv/config';
import sql from 'mssql';

const configuracion = {
  server: process.env.DB_SERVER,
  port: process.env.DB_PORT ? Number(process.env.DB_PORT) : undefined,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  options: { encrypt: true, trustServerCertificate: true },
  pool: { max: 5, min: 0, idleTimeoutMillis: 30000 },
};

// Un solo pool de conexiones para todo el servidor.
let promesaPool;
function obtenerPool() {
  if (!promesaPool) {
    promesaPool = new sql.ConnectionPool(configuracion).connect().catch((error) => {
      promesaPool = undefined; // si falla, se reintenta en la próxima llamada
      throw error;
    });
  }
  return promesaPool;
}

// ÚNICA puerta de entrada a la base de datos: solo ejecuta procedimientos
// almacenados (nunca SQL suelto).
//   nombreSP: 'dbo.sp_ListarCuentasUsuario'
//   entradas: { inIdUsuario: [sql.Int, 5], inNumeroCuenta: [sql.VarChar(16), '11000001'] }
// Devuelve { codigo, recordsets }: el valor de @outResultCode y las consultas
// SELECT que devolvió el SP, en orden.
export async function ejecutarSP(nombreSP, entradas = {}) {
  const pool = await obtenerPool();
  const peticion = pool.request();
  for (const [nombre, [tipo, valor]] of Object.entries(entradas)) {
    peticion.input(nombre, tipo, valor);
  }
  peticion.output('outResultCode', sql.Int);
  const resultado = await peticion.execute(nombreSP);
  return { codigo: resultado.output.outResultCode, recordsets: resultado.recordsets };
}

export { sql };