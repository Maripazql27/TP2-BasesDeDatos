// Pide los estados con consultarEstados() (sp_ConsultarEstadosCuenta): todos,
// del más reciente al más antiguo. Al hacer clic en uno se abre el detalle con
// sus movimientos (pantalla Movimientos.jsx). Al navegar se le pasa la fila
// del estado elegido, para que esa pantalla muestre también sus valores.
import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { consultarEstados } from '../api';
import { dinero as formatearDinero } from '../formato';

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
    return formatearDinero(e.SimboloMoneda, valor);
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
                  <th className="num">Saldo inicial</th>
                  <th className="num">Saldo final</th>
                  <th className="num">Saldo mínimo</th>
                  <th className="num">Intereses</th>
                  <th className="num">Operaciones ATM</th>
                  <th className="num">Operaciones cajero humano</th>
                  <th className="num">Operaciones SINPE</th>
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
                    <td className="num">{dinero(e, e.SaldoInicial)}</td>
                    <td className="num">{dinero(e, e.SaldoFinal)}</td>
                    <td className="num">{dinero(e, e.SaldoMinimo)}</td>
                    <td className="num">{dinero(e, e.InteresesAcumulados)}</td>
                    <td className="num">{e.CantOperacionesATM}</td>
                    <td className="num">{e.CantOperacionesHumano}</td>
                    <td className="num">{e.CantOperacionesSinpe}</td>
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