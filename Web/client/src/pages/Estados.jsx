import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { consultarEstados } from '../api';

const formatoMoneda = new Intl.NumberFormat('es-CR', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export default function Estados() {
  const { numeroCuenta } = useParams();
  const [estados, setEstados] = useState([]);
  const [cargando, setCargando] = useState(true);


  // Se vuelve a ejecutar si cambia la cuenta.
  useEffect(() => {
    async function cargar() {
      const respuesta = await consultarEstados(numeroCuenta);
      if (respuesta.ok) setEstados(respuesta.datos);
      setCargando(false);
    }
    cargar();
  }, [numeroCuenta]);

  return (
    <main className="pagina">
      <header className="encabezado">
        <h1>Estados de cuenta {numeroCuenta}</h1>
        <Link to="/cuentas">Volver a mis cuentas</Link>
      </header>

      {cargando && <p>Cargando...</p>}
      {!cargando && estados.length === 0 && <p>No hay estados de cuenta.</p>}

      {estados.length > 0 && (
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
                <th>Retiros</th>
                <th>Depósitos</th>
                <th>SINPE entrantes</th>
                <th>SINPE salientes</th>
              </tr>
            </thead>
            <tbody>
              {estados.map((e) => (
                // Cliqueable, pero en TP2 el clic no hace nada (lo pide el enunciado).
                <tr key={e.IdEstadoCuenta} className="fila-clic" onClick={() => {}}>
                  <td>{e.FechaEmision}</td>
                  <td>{e.FechaInicio}</td>
                  <td>{e.FechaFin}</td>
                  <td>{formatoMoneda.format(e.SaldoInicial)}</td>
                  <td>{formatoMoneda.format(e.SaldoFinal)}</td>
                  <td>{formatoMoneda.format(e.SaldoMinimo)}</td>
                  <td>{formatoMoneda.format(e.InteresesAcumulados)}</td>
                  <td>{e.CantRetiros}</td>
                  <td>{e.CantDepositos}</td>
                  <td>{e.CantSinpeEntrantes}</td>
                  <td>{e.CantSinpeSalientes}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </main>
  );
}