//   - Resumen: generados, enviados, pendientes y con error de envío.
//   - Botón para enviar los pendientes. El servidor manda cada correo y lo
//     marca como enviado (sp_RegistrarEnvioComprobante), así no se repite.
//   - Tabla con cada comprobante; "Ver" muestra el texto del correo.
// sp_AplicarMovimiento deja los comprobantes listos al aplicar cada compra,
// retiro o depósito; aquí solo se envían, después de esa transacción.

import { useEffect, useState } from 'react';
import { consultarComprobantes, enviarComprobantes } from '../api';

// Mensaje que se muestra después de presionar "Enviar".
function resultadoDelEnvio(respuesta) {
  if (!respuesta.ok) return { tipo: 'error', texto: respuesta.mensaje };
  if (respuesta.total === 0) return { tipo: 'ok', texto: 'No había comprobantes pendientes.' };

  let texto =
    respuesta.enviados === 1
      ? 'Se envió 1 comprobante.'
      : `Se enviaron ${respuesta.enviados} comprobantes.`;
  if (respuesta.fallidos > 0) {
    texto += ` ${respuesta.fallidos} no se pudieron enviar: siguen pendientes y se reintentan en el próximo envío.`;
  }
  if (respuesta.sinRegistrar > 0) {
    texto += ` ${respuesta.sinRegistrar} no se pudieron marcar en la base (ver la consola del servidor).`;
  }
  const hayProblemas = respuesta.fallidos > 0 || respuesta.sinRegistrar > 0;
  return { tipo: hayProblemas ? 'error' : 'ok', texto };
}

// Celda "Estado" de un comprobante.
function EstadoEnvio({ comprobante }) {
  if (comprobante.FlagEnviado) {
    return <td className="estado-ok">Enviado {comprobante.FechaHoraEnvio}</td>;
  }
  if (comprobante.CantIntentosEnvio > 0) {
    const veces =
      comprobante.CantIntentosEnvio === 1 ? '1 vez' : `${comprobante.CantIntentosEnvio} veces`;
    const detalle = comprobante.UltimoErrorEnvio ?? '';
    const corto = detalle.length > 60 ? `${detalle.slice(0, 60)}...` : detalle;
    return (
      <td className="estado-error" title={detalle}>
        Pendiente: falló {veces} ({corto})
      </td>
    );
  }
  return <td className="estado-pendiente">Pendiente</td>;
}

// Solo dibuja (no le pide nada al servidor): así se puede probar con datos fijos.
export function VistaComprobantes({ datos, error, enviando, mensaje, onEnviar }) {
  const resumen = datos?.resumen;
  const comprobantes = datos?.comprobantes ?? [];
  const pendientes = resumen?.CantPendientes ?? 0;

  return (
    <section>
      <h2>Comprobantes por correo</h2>
      <p>
        Cada compra, retiro o depósito deja un comprobante con el correo para el dueño de la
        cuenta. Los correos se envían desde aquí, después de que el movimiento ya quedó
        guardado.
      </p>

      {error && <p className="error">{error}</p>}

      {resumen && (
        <>
          <section className="resumen">
            <div>
              <span>Generados</span>
              <strong>{resumen.CantGenerados}</strong>
            </div>
            <div>
              <span>Enviados</span>
              <strong>{resumen.CantEnviados}</strong>
            </div>
            <div>
              <span>Pendientes</span>
              <strong>{resumen.CantPendientes}</strong>
            </div>
            <div>
              <span>Con error de envío</span>
              <strong>{resumen.CantConError}</strong>
            </div>
          </section>
          {datos.envio && <p className="nota">Modo de envío: {datos.envio.descripcion}.</p>}
          <p>
            <button onClick={onEnviar} disabled={enviando || pendientes === 0}>
              {enviando ? 'Enviando...' : `Enviar comprobantes pendientes (${pendientes})`}
            </button>
          </p>
        </>
      )}

      {mensaje && (
        <p className={mensaje.tipo === 'ok' ? 'mensaje-ok' : 'mensaje-error'}>{mensaje.texto}</p>
      )}

      {comprobantes.length > 0 && (
        <div className="tabla-scroll tabla-alta">
          <table>
            <thead>
              <tr>
                <th className="num">N.º</th>
                <th>Fecha</th>
                <th>Asunto</th>
                <th>Para</th>
                <th>Estado</th>
                <th>Correo</th>
              </tr>
            </thead>
            <tbody>
              {comprobantes.map((c) => (
                <tr key={c.IdComprobante}>
                  <td className="num">{c.IdComprobante}</td>
                  <td>{c.FechaOperacion}</td>
                  <td>{c.Asunto}</td>
                  <td>{c.EmailDestino}</td>
                  <EstadoEnvio comprobante={c} />
                  <td>
                    <details>
                      <summary>Ver</summary>
                      <pre className="texto-correo">{c.TextoEmail}</pre>
                    </details>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

// "version" viene de la página: cuando allá se presiona "Actualizar", esta
// sección también vuelve a pedir sus datos.
export default function SeccionComprobantes({ version }) {
  const [datos, setDatos] = useState(null);
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);
  const [mensaje, setMensaje] = useState(null); // { tipo: 'ok' | 'error', texto }
  // Sube en 1 después de cada envío, para volver a pedir la lista.
  const [recargas, setRecargas] = useState(0);

  useEffect(() => {
    async function cargar() {
      const respuesta = await consultarComprobantes();
      if (respuesta.ok) {
        setDatos(respuesta);
        setError('');
      } else {
        setError(respuesta.mensaje);
      }
    }
    cargar();
  }, [version, recargas]);

  async function enviar() {
    setEnviando(true);
    setMensaje(null);
    const respuesta = await enviarComprobantes();
    setEnviando(false);
    setMensaje(resultadoDelEnvio(respuesta));
    setRecargas((v) => v + 1);
  }

  return (
    <VistaComprobantes
      datos={datos}
      error={error}
      enviando={enviando}
      mensaje={mensaje}
      onEnviar={enviar}
    />
  );
}
