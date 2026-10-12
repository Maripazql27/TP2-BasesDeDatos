// =============================================================================
// LISTA DE CUENTAS DEL USUARIO
// Al abrirse pide las cuentas con listarCuentas() (sp_ListarCuentasUsuario)
// y las muestra en una lista. Cada cuenta tiene enlaces a sus beneficiarios y
// a sus estados de cuenta.
// =============================================================================
import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { listarCuentas, cerrarSesion } from '../api';

// Formatea números como dinero: 1000000 -> "1 000 000,00" (formato de Costa Rica).
const formatoMoneda = new Intl.NumberFormat('es-CR', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

// usuario: quién inició sesión. onLogout: función de App para borrar la sesión.
export default function Cuentas({ usuario, onLogout }) {
  const [cuentas, setCuentas] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const navegar = useNavigate();

  // useEffect con [] = se ejecuta UNA vez, cuando la pantalla aparece.
  useEffect(() => {
    async function cargar() {
      const respuesta = await listarCuentas();
      if (respuesta.ok) {
        setCuentas(respuesta.datos);
      } else if (respuesta.codigo === 50001) {
        // 50001 aquí = la sesión expiró (o el servidor se reinició): al login.
        onLogout();
        navegar('/login');
        return;
      } else {
        setError(respuesta.mensaje);
      }
      setCargando(false);
    }
    cargar();
  }, []);

  async function salir() {
    await cerrarSesion(); // el servidor registra el logout en la bitácora y destruye la sesión
    onLogout();           // borra la copia del usuario en la web
    navegar('/login');
  }

  return (
    <main className="pagina">
      <header className="encabezado">
        <h1>Mis cuentas</h1>
        <div>
          <span>Hola, {usuario.nombreUsuario}. </span>
          <button onClick={salir}>Cerrar sesión</button>
        </div>
      </header>

      {cargando && <p>Cargando...</p>}
      {error && <p className="error">{error}</p>}
      {!cargando && !error && cuentas.length === 0 && <p>No tiene cuentas disponibles.</p>}

      <div className="lista">
        {/* "key" ayuda a React a identificar cada elemento de la lista */}
        {cuentas.map((c) => (
          <section key={c.IdCuenta} className="tarjeta-cuenta">
            <h2>Cuenta {c.NumeroCuenta}</h2>
            <p>Tipo: {c.NombreTipoCuenta}</p>
            <p>Saldo: {formatoMoneda.format(c.Saldo)}</p>
            <Link to={`/cuentas/${c.NumeroCuenta}/beneficiarios`}>
              Beneficiarios
            </Link>
            {' | '}
            <Link to={`/cuentas/${c.NumeroCuenta}/estados`}>
              Estados de cuenta
            </Link>
          </section>
        ))}
      </div>
    </main>
  );
}