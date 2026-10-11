import { useNavigate } from 'react-router-dom';

export default function Cuentas({ usuario, onLogout }) {
  const navegar = useNavigate();

  function salir() {
    onLogout();
    navegar('/login');
  }

  return (
    <main className="tarjeta">
      <h1>Mis cuentas</h1>
      <p>Hola, {usuario.nombreUsuario}.</p>
      <p>(Aquí irá la lista de cuentas.)</p>
      <button onClick={salir}>Cerrar sesión</button>
    </main>
  );
}