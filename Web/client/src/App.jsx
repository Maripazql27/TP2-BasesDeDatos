import { useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/Login';
import Cuentas from './pages/Cuentas';

// Si no hay usuario en sesión, manda a la pantalla de login.
function RutaProtegida({ usuario, children }) {
  return usuario ? children : <Navigate to="/login" replace />;
}

export default function App() {
  const [usuario, setUsuario] = useState(null);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login onLogin={setUsuario} />} />
        <Route
          path="/cuentas"
          element={
            <RutaProtegida usuario={usuario}>
              <Cuentas usuario={usuario} onLogout={() => setUsuario(null)} />
            </RutaProtegida>
          }
        />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}