// Pide los estados con consultarEstados() (sp_ConsultarEstadosCuenta): todos,
// del más reciente al más antiguo. Al hacer clic en uno se abre el detalle con
// sus movimientos (pantalla Movimientos.jsx). Al navegar se le pasa la fila
// del estado elegido, para que esa pantalla muestre también sus valores.
import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { consultarEstados } from '../api';

const formatoMoneda = new Intl.NumberFormat('es-CR', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export default function Estados() {
  // useParams lee la parte variable de la URL: /cuentas/ESTE_VALOR/estados
  const { numeroCuenta } = useParams();
  const navegar = useNavigate();
  const [estados, setEstados] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    async function cargar() {
      const respuesta = await consultarEstados(numeroCuenta);
      if (respuesta.ok) setEstados(respuesta.datos);
      else setError(respuesta.mensaje); // p. ej. 50002: no tiene acceso a esa cuenta
      setCargando(false);
    }
    cargar();
  }, [numeroCuenta]);

  // Si el SP devuelve el símbolo de la moneda se muestra; si no, no se muestra nada.
  function dinero(e, valor) {
    return `${e.SimboloMoneda ?? ''} ${formatoMoneda.format(valor)}`.trim();
  }

  return (
    <main className="pagina pagina-ancha">
      <header className="encabezado">
        <h1>Estados de cuenta {numeroCuenta}</h1>
        <Link to="/cuentas">Volver a mis cuentas</Link>
      </header>

      {cargando && <p>Cargando...</p>}
      {error && <p className="error">{error}</p>}
      {!cargando && !error && estados.length === 0 && <p>No hay estados de cuenta.</p>}

      {estados.length > 0 && (
        <>
          <p>Haga clic en un estado para ver sus movimientos.</p>
          <div className="tabla-scroll">
            <table>
              <thead>
                <tr>
                  <th>Emisión</th>
                  <th>Inicio</th>
                  <th>Fin</th>
                  <th>Saldo inicial</th>
                  <th>Saldo final</th>
                  <th>Saldo mínimo</th>
                  <th>Intereses</th>
                  <th>Operaciones ATM</th>
                  <th>Operaciones cajero humano</th>
                  <th>Operaciones SINPE</th>
                </tr>
              </thead>
              <tbody>
                {estados.map((e) => (
                  <tr
                    key={e.IdEstadoCuenta}
                    className="fila-clic"
                    onClick={() =>
                      navegar(`/cuentas/${numeroCuenta}/estados/${e.IdEstadoCuenta}`, {
                        state: { estado: e },
                      })
                    }
                  >
                    <td>{e.FechaEmision}</td>
                    <td>{e.FechaInicio}</td>
                    <td>{e.FechaFin}</td>
                    <td>{dinero(e, e.SaldoInicial)}</td>
                    <td>{dinero(e, e.SaldoFinal)}</td>
                    <td>{dinero(e, e.SaldoMinimo)}</td>
                    <td>{dinero(e, e.InteresesAcumulados)}</td>
                    <td>{e.CantOperacionesATM}</td>
                    <td>{e.CantOperacionesHumano}</td>
                    <td>{e.CantOperacionesSinpe}</td>
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