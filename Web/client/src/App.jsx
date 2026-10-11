// =============================================================================
// App.jsx — COMPONENTE RAÍZ: define las rutas (URLs) y quién tiene sesión.
//
// Rutas:
//   /login                                  -> Login
//   /cuentas                                -> Cuentas
//   /cuentas/:numeroCuenta/estados          -> Estados
//   /cuentas/:numeroCuenta/beneficiarios    -> Beneficiarios
// Las tres últimas están protegidas: sin sesión, redirigen al login.
//
// OJO: la protección de aquí es solo VISUAL (comodidad). La seguridad real
// está en el servidor (sesión) y en los SP (validan el acceso a la cuenta).
// =============================================================================
import { useEffect, useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/login';
import Cuentas from './pages/cuentas';
import Estados from './pages/Estados';
import Beneficiarios from './pages/Beneficiarios';
import { obtenerSesion } from './api';

// Si no hay usuario en sesión, manda a la pantalla de login.
// "children" es la pantalla protegida que se quiere mostrar.
function RutaProtegida({ usuario, children }) {
  return usuario ? children : <Navigate to="/login" replace />;
}

export default function App() {
  // Usuario en sesión (null = nadie). La sesión REAL vive en el servidor; aquí
  // solo se guarda una copia para saber qué mostrar.
  const [usuario, setUsuario] = useState(null);
  // true mientras se le pregunta al servidor si ya había una sesión abierta.
  const [verificando, setVerificando] = useState(true);

  // Al cargar la página (incluido F5) se pregunta al servidor quién tiene sesión.
  // Así recargar no saca al usuario. useEffect con [] = una sola vez al aparecer.
  useEffect(() => {
    async function verificar() {
      const respuesta = await obtenerSesion();
      if (respuesta.ok) setUsuario(respuesta.usuario);
      setVerificando(false);
    }
    verificar();
  }, []);

  // Sin esta espera, al recargar se vería el login un instante (y las rutas
  // protegidas redirigirían) antes de saber si hay sesión.
  if (verificando) return <p className="pagina">Cargando...</p>;

  return (
    <BrowserRouter>
      <Routes>
        {/* onLogin guarda el usuario cuando el login sale bien */}
        <Route path="/login" element={<Login onLogin={setUsuario} />} />
        <Route
          path="/cuentas"
          element={
            <RutaProtegida usuario={usuario}>
              <Cuentas usuario={usuario} onLogout={() => setUsuario(null)} />
            </RutaProtegida>
          }
        />
        <Route
          path="/cuentas/:numeroCuenta/estados"
          element={
            <RutaProtegida usuario={usuario}>
              <Estados />
            </RutaProtegida>
          }
        />
        <Route
          path="/cuentas/:numeroCuenta/beneficiarios"
          element={
            <RutaProtegida usuario={usuario}>
              <Beneficiarios />
            </RutaProtegida>
          }
        />
        {/* Cualquier otra dirección vuelve al login */}
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}