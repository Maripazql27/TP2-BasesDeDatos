// =============================================================================
// Movimientos.jsx — MOVIMIENTOS DE UN ESTADO DE CUENTA (TP3)
// Toma de la URL la cuenta y el estado, pide los movimientos con
// consultarMovimientos() (sp_ConsultarMovimientosEstadoCuenta, orden
// cronológico) y muestra: fecha, tipo, descripción (la del XML), monto en la
// moneda de la cuenta (negativo si es débito) y el nuevo saldo.
// =============================================================================
import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { consultarMovimientos } from '../api';

const formatoMoneda = new Intl.NumberFormat('es-CR', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export default function Movimientos() {
  const { numeroCuenta, idEstado } = useParams();
  const [movimientos, setMovimientos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function cargar() {
      const respuesta = await consultarMovimientos(numeroCuenta, idEstado);
      if (respuesta.ok) setMovimientos(respuesta.datos);
      else setError(respuesta.mensaje); // p. ej. 50002: sin acceso a la cuenta o estado ajeno
      setCargando(false);
    }
    cargar();
  }, [numeroCuenta, idEstado]);

  const simbolo = movimientos.length > 0 ? movimientos[0].SimboloMoneda : '';
  const nombreMoneda = movimientos.length > 0 ? movimientos[0].NombreMoneda : '';

  return (
    <main className="pagina">
      <header className="encabezado">
        <h1>Movimientos de la cuenta {numeroCuenta}</h1>
        <Link to={`/cuentas/${numeroCuenta}/estados`}>Volver a los estados de cuenta</Link>
      </header>

      {cargando && <p>Cargando...</p>}
      {error && <p className="error">{error}</p>}
      {!cargando && !error && movimientos.length === 0 && (
        <p>Este estado de cuenta no tiene movimientos.</p>
      )}

      {movimientos.length > 0 && (
        <>
          <p>Moneda de la cuenta: {nombreMoneda} ({simbolo})</p>
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>Fecha</th>
                  <th>Tipo</th>
                  <th>Descripción</th>
                  <th>Monto</th>
                  <th>Nuevo saldo</th>
                </tr>
              </thead>
              <tbody>
                {movimientos.map((m) => (
                  <tr key={m.IdMovimiento}>
                    <td>{m.FechaMovimiento}</td>
                    <td>{m.TipoMovimiento}</td>
                    <td>{m.Descripcion}</td>
                    <td>{`${m.SimboloMoneda} ${formatoMoneda.format(m.MontoConSigno)}`}</td>
                    <td>{`${m.SimboloMoneda} ${formatoMoneda.format(m.SaldoPosterior)}`}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </main>
  );
}