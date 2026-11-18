// Arriba muestra los valores del estado elegido: período, saldo al inicio, al
// final, saldo mínimo, intereses y cantidad de operaciones en ATM, en cajero
// humano y SINPE. Debajo, sus movimientos en orden cronológico
// (sp_ConsultarMovimientosEstadoCuenta): fecha, tipo, descripción (la del
// XML), monto en la moneda de la cuenta (negativo si es débito) y nuevo saldo.
// Los valores del estado llegan desde la lista de estados al hacer clic; si la
// página se abre directo (sin pasar por la lista) se piden con consultarEstados().

import { useEffect, useState } from 'react';
import { Link, useLocation, useParams } from 'react-router-dom';
import { consultarEstados, consultarMovimientos } from '../api';

const formatoMoneda = new Intl.NumberFormat('es-CR', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export default function Movimientos() {
  const { numeroCuenta, idEstado } = useParams();
  const location = useLocation();
  const [estado, setEstado] = useState(location.state?.estado ?? null);
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

  // Página abierta directo: se buscan los valores del estado en la lista de estados.
  useEffect(() => {
    if (estado) return;
    async function cargarEstado() {
      const respuesta = await consultarEstados(numeroCuenta);
      if (respuesta.ok) {
        const encontrado = respuesta.datos.find(
          (e) => String(e.IdEstadoCuenta) === String(idEstado)
        );
        if (encontrado) setEstado(encontrado);
      }
    }
    cargarEstado();
  }, [estado, numeroCuenta, idEstado]);

  // La moneda la trae el SP de movimientos (y el de estados, si se le agrega).
  const simbolo = movimientos[0]?.SimboloMoneda ?? estado?.SimboloMoneda ?? '';
  const nombreMoneda = movimientos[0]?.NombreMoneda ?? '';

  function dinero(valor) {
    return `${simbolo} ${formatoMoneda.format(valor)}`.trim();
  }

  return (
    <main className="pagina">
      <header className="encabezado">
        <h1>Estado de cuenta de la cuenta {numeroCuenta}</h1>
        <Link to={`/cuentas/${numeroCuenta}/estados`}>Volver a los estados de cuenta</Link>
      </header>

      {estado && (
        <section className="resumen">
          <div>
            <span>Período</span>
            <strong>
              {estado.FechaInicio} a {estado.FechaFin}
            </strong>
          </div>
          <div>
            <span>Fecha de emisión</span>
            <strong>{estado.FechaEmision}</strong>
          </div>
          <div>
            <span>Saldo al inicio</span>
            <strong>{dinero(estado.SaldoInicial)}</strong>
          </div>
          <div>
            <span>Saldo al final</span>
            <strong>{dinero(estado.SaldoFinal)}</strong>
          </div>
          <div>
            <span>Saldo mínimo</span>
            <strong>{dinero(estado.SaldoMinimo)}</strong>
          </div>
          <div>
            <span>Intereses</span>
            <strong>{dinero(estado.InteresesAcumulados)}</strong>
          </div>
          <div>
            <span>Operaciones en ATM</span>
            <strong>{estado.CantOperacionesATM}</strong>
          </div>
          <div>
            <span>Operaciones en cajero humano</span>
            <strong>{estado.CantOperacionesHumano}</strong>
          </div>
          <div>
            <span>Operaciones SINPE</span>
            <strong>{estado.CantOperacionesSinpe}</strong>
          </div>
        </section>
      )}

      <h2>Movimientos</h2>
      {cargando && <p>Cargando...</p>}
      {error && <p className="error">{error}</p>}
      {!cargando && !error && movimientos.length === 0 && (
        <p>Este estado de cuenta no tiene movimientos.</p>
      )}

      {movimientos.length > 0 && (
        <>
          <p>
            Moneda de la cuenta: {nombreMoneda} ({simbolo})
          </p>
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
