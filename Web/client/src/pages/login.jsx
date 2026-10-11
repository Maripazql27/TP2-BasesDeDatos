import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { iniciarSesion } from '../api';

// onLogin: función que App nos da para guardar el usuario en sesión.
export default function Login({ onLogin }) {
  // Estado de los campos y del mensaje de error.
  const [nombreUsuario, setNombreUsuario] = useState('');
  const [clave, setClave] = useState('');
  const [error, setError] = useState('');
  const navegar = useNavigate(); // para cambiar de pantalla desde el código


  
  // Se ejecuta al enviar el formulario.
  async function enviar(evento) {
    evento.preventDefault(); // evita que el navegador recargue la página
    setError('');
    const respuesta = await iniciarSesion(nombreUsuario, clave);
    if (respuesta.ok) {
      onLogin(respuesta.usuario);
      navegar('/cuentas');
    } else {
      setError(respuesta.mensaje);
    }
  }

  return (
    <main className="tarjeta">
      <h1>Cuenta de Ahorros</h1>
      <form onSubmit={enviar}>
        <label>
          Usuario
          <input
            value={nombreUsuario}
            onChange={(e) => setNombreUsuario(e.target.value)}
            maxLength={64}
            required
          />
        </label>
        <label>
          Contraseña
          <input
            type="password"
            value={clave}
            onChange={(e) => setClave(e.target.value)}
            maxLength={128}
            required
          />
        </label>
        {error && <p className="error">{error}</p>}
        <button type="submit">Ingresar</button>
      </form>
    </main>
  );
}