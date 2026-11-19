// Muestra lo que registra Simulacion_TP3.sql (sp_ConsultarControlSimulacion):
//   - resumen: fechas del XML, terminadas, próxima pendiente y totales;
//   - corridas: cada vez que se ejecutó el script y cómo terminó;
//   - fechas: hasta dónde llegó cada fecha (altas, movimientos y cierres).
// Sirve para ver que la simulación no se repite, no brinca fechas y que, si se
// corta, la siguiente corrida reanuda desde lo último procesado.

import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { consultarControlSimulacion } from '../api';
import SeccionComprobantes from '../components/Comprobantes';

// Valores de CodigoResultado en dbo.CorridaSimulacion
const RESULTADOS = {
  0: 'Completa',
  1: 'Nada pendiente (no repitió nada)',
  2: 'Detenida por error o interrumpida',
  3: 'Detenida a propósito (prueba)',
};

export default function Simulacion() {
  const [datos, setDatos] = useState(null);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  // Cada vez que cambia "version" se vuelven a pedir los datos. Empieza en 0
  // (al abrir la pantalla) y el botón "Actualizar" la sube en 1.
  const [version, setVersion] = useState(0);

  useEffect(() => {
    async function cargar() {
      const respuesta = await consultarControlSimulacion();
      if (respuesta.ok) {
        setDatos(respuesta);
        setError('');
      } else {
        setError(respuesta.mensaje);
      }
      setCargando(false);
    }
    cargar();
  }, [version]);

  // Útil mientras se prueba la reanudación: se corre el script y se actualiza.
  function actualizar() {
    setCargando(true);
    setVersion((v) => v + 1);
  }

  const resumen = datos?.resumen;
  const corridas = datos?.corridas ?? [];
  const fechas = datos?.fechas ?? [];
  const aMedias = fechas.find((f) => !f.FlagTerminada);

  return (
    <main className="pagina pagina-ancha">
      <header className="encabezado">
        <h1>Control de la simulación</h1>
        <div>
          <button onClick={actualizar} disabled={cargando}>
            Actualizar
          </button>{' '}
          <Link to="/cuentas">Volver a mis cuentas</Link>
        </div>
      </header>
      <p>
        Solo lectura. Lo registra el script Simulacion_TP3.sql en las tablas
        CorridaSimulacion y ControlSimulacion.
      </p>

      {cargando && <p>Cargando...</p>}
      {error && <p className="error">{error}</p>}
      {!cargando && !error && resumen && resumen.CantCorridas === 0 && (
        <p>La simulación todavía no se ha corrido.</p>
      )}

      {resumen && resumen.CantCorridas > 0 && (
        <>
          <section className="resumen">
            <div>
              <span>Fechas del XML</span>
              <strong>
                {resumen.FechaInicioXml} a {resumen.FechaFinXml}
              </strong>
            </div>
            <div>
              <span>Fechas terminadas</span>
              <strong>
                {resumen.CantFechasTerminadas} de {resumen.CantFechasXml}
              </strong>
            </div>
            <div>
              <span>Última fecha terminada</span>
              <strong>{resumen.UltimaFechaTerminada ?? '—'}</strong>
            </div>
            <div>
              <span>Próxima fecha pendiente</span>
              <strong>{resumen.ProximaFechaPendiente ?? 'Ninguna: simulación completa'}</strong>
            </div>
            <div>
              <span>Movimientos del XML</span>
              <strong>
                {resumen.TotalMovimientosAplicados} aplicados,{' '}
                {resumen.TotalMovimientosRechazados} rechazados
              </strong>
            </div>
            <div>
              <span>Cierres de estado de cuenta</span>
              <strong>{resumen.TotalCierres}</strong>
            </div>
            <div>
              <span>Corridas del script</span>
              <strong>{resumen.CantCorridas}</strong>
            </div>
          </section>

          {aMedias && (
            <p className="alerta">
              La fecha {aMedias.FechaOperacion} quedó a medias: altas{' '}
              {aMedias.FlagAltasProcesadas ? 'hechas' : 'pendientes'}, movimiento{' '}
              {aMedias.UltimoMovimientoProcesado} de {aMedias.CantMovimientosXml}, cierres
              hasta la cuenta {aMedias.NumeroUltimaCuentaCerrada ?? 'ninguna'}
              {aMedias.CodigoError ? ` (error ${aMedias.CodigoError})` : ''}. La próxima
              corrida reanuda desde ahí.
            </p>
          )}

          <h2>Corridas</h2>
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>#</th>
                  <th>Inicio</th>
                  <th>Fin</th>
                  <th>Desde</th>
                  <th>Hasta</th>
                  <th>Fechas terminadas</th>
                  <th>Resultado</th>
                  <th>Mensaje</th>
                </tr>
              </thead>
              <tbody>
                {corridas.map((c) => (
                  <tr key={c.IdCorrida}>
                    <td>{c.IdCorrida}</td>
                    <td>{c.FechaHoraInicio}</td>
                    <td>{c.FechaHoraFin ?? '—'}</td>
                    <td>{c.FechaDesde ?? '—'}</td>
                    <td>{c.FechaHasta ?? '—'}</td>
                    <td>{c.CantFechasTerminadas}</td>
                    <td>
                      {c.CodigoResultado === null
                        ? 'En curso o sin terminar'
                        : RESULTADOS[c.CodigoResultado] ?? c.CodigoResultado}
                    </td>
                    <td>{c.Mensaje ?? ''}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <SeccionComprobantes version={version} />

          <h2>Fechas de operación</h2>
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>Fecha</th>
                  <th>Estado</th>
                  <th>Altas</th>
                  <th>Movimientos procesados</th>
                  <th>Aplicados</th>
                  <th>Rechazados</th>
                  <th>Cierres</th>
                  <th>Última cuenta cerrada</th>
                  <th>Intentos</th>
                  <th>Corrida</th>
                  <th>Terminó</th>
                </tr>
              </thead>
              <tbody>
                {fechas.map((f) => (
                  <tr key={f.FechaOperacion} className={f.FlagTerminada ? '' : 'fila-pendiente'}>
                    <td>{f.FechaOperacion}</td>
                    <td className={f.FlagTerminada ? 'estado-ok' : 'estado-pendiente'}>
                      {f.FlagTerminada ? 'Terminada' : 'A medias'}
                    </td>
                    <td>{f.FlagAltasProcesadas ? 'Sí' : 'No'}</td>
                    <td>
                      {f.UltimoMovimientoProcesado} de {f.CantMovimientosXml}
                    </td>
                    <td>{f.CantMovimientosAplicados}</td>
                    <td>{f.CantMovimientosRechazados}</td>
                    <td>{f.CantCierres}</td>
                    <td>{f.NumeroUltimaCuentaCerrada ?? '—'}</td>
                    <td>{f.CantIntentos > 1 ? `${f.CantIntentos} (reanudada)` : f.CantIntentos}</td>
                    <td>{f.IdCorridaSimulacion}</td>
                    <td>{f.FechaHoraFin ?? '—'}</td>
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