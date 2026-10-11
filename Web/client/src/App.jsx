import { useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/Login';
import Cuentas from './pages/Cuentas';
import Estados from './pages/Estados';
import Beneficiarios from './pages/Beneficiarios';

// Si no hay usuario en sesión, manda a la pantalla de login.
// "children" es la pantalla protegida que se quiere mostrar.
function RutaProtegida({ usuario, children }) {
  return usuario ? children : <Navigate to="/login" replace />;
}

export default function App() {
    // Usuario en sesión (null = nadie). Vive en memoria: al recargar la página
  // se pierde. Cuando exista el servidor, la sesión la guardará él.
  const [usuario, setUsuario] = useState(null);

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
        />        <Route
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