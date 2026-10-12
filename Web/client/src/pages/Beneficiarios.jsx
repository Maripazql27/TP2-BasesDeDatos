// =============================================================================
// Beneficiarios.jsx — PANTALLA PRINCIPAL DE EDICIÓN DE BENEFICIARIOS


import { useEffect, useRef, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import {
  listarBeneficiarios,
  listarParentezcos,
  listarTiposDocumento,
  agregarBeneficiario,
  actualizarBeneficiario,
  actualizarPorcentajes,
  eliminarBeneficiario,
} from '../api';
import FormularioBeneficiario from '../components/FormularioBeneficiario';
import EditorPorcentajes from '../components/EditorPorcentajes';

// Texto exacto que pide el enunciado.
const TEXTO_ALERTA =
  'la suma de los porcentajes de sus beneficiarios no suma 100, favor corregir y cancelar la edición';

export default function Beneficiarios() {
  const { numeroCuenta } = useParams(); // cuenta tomada de la URL

  // --- Estado de la pantalla ---
  const [beneficiarios, setBeneficiarios] = useState([]); // lista activa
  const [resumen, setResumen] = useState(null);           // suma y cantidad
  const [parentezcos, setParentezcos] = useState([]);     // catálogo
  const [tiposDocumento, setTiposDocumento] = useState([]); // catálogo
  const [cargando, setCargando] = useState(true);
  const [mensaje, setMensaje] = useState(null); // { tipo: 'ok' | 'error', texto }
  // Qué formulario está abierto: null (ninguno), 'agregar', o el beneficiario
  // cuyos datos se editan.
  const [formulario, setFormulario] = useState(null);
  const [editandoPorcentajes, setEditandoPorcentajes] = useState(false);
  // "version" es un contador: cada vez que cambia, el useEffect de abajo vuelve
  // a consultar la lista. Es la forma de "refrescar" tras guardar un cambio.
  const [version, setVersion] = useState(0);
  // useRef guarda un valor que NO provoca que la pantalla se redibuje.
  // Aquí marca "después de cargar la lista, revisa si la suma es 100".
  // Se activa tras agregar o desactivar un beneficiario.
  const revisarSuma = useRef(false);

  // Catálogos para los desplegables (una sola vez, al abrir la pantalla).
  useEffect(() => {
    async function cargarCatalogos() {
      const p = await listarParentezcos();
      const t = await listarTiposDocumento();
      if (p.ok) setParentezcos(p.datos);
      if (t.ok) setTiposDocumento(t.datos);
    }
    cargarCatalogos();
  }, []);

  // Lista de beneficiarios y suma de porcentajes. Se repite si cambia la cuenta
  // o si "version" cambia (después de guardar algo).
  useEffect(() => {
    async function cargar() {
      const r = await listarBeneficiarios(numeroCuenta);
      if (r.ok) {
        setBeneficiarios(r.beneficiarios);
        setResumen(r.resumen);
        if (revisarSuma.current) {
          revisarSuma.current = false;
          // Si tras agregar/desactivar la suma quedó distinta de 100, se abre
          // sola la edición de porcentajes para corregirla.
          if (r.resumen.CantidadBeneficiarios > 0 && r.resumen.SumaPorcentajes !== 100) {  // check: nombre de columna que devuelve el SP
            setEditandoPorcentajes(true);
            setMensaje({
              tipo: 'error',
              texto: 'Ajuste los porcentajes de todos los beneficiarios para que sumen 100.',
            });
          }
        }
      }
      setCargando(false);
    }
    cargar();
  }, [numeroCuenta, version]);

  // Agregar un beneficiario nuevo o editar nombre y parentesco.
  async function guardar(datos) {
    const esEdicion = formulario !== 'agregar';
    const r = esEdicion
      ? await actualizarBeneficiario(formulario.IdBeneficiario, datos)
      : await agregarBeneficiario(numeroCuenta, datos);
    if (r.ok) {
      setMensaje({ tipo: 'ok', texto: 'Cambios guardados.' });
      setFormulario(null);
      revisarSuma.current = !esEdicion; // al agregar, revisar la suma
      setVersion(version + 1);          // provoca nueva consulta
    } else {
      // Se deja el formulario abierto para que el usuario corrija.
      setMensaje({ tipo: 'error', texto: r.mensaje });
    }
  }

  // Guardar los porcentajes de todos (todo o nada).
  async function guardarPorcentajes(lista) {
    const r = await actualizarPorcentajes(numeroCuenta, lista);
    if (r.ok) {
      setMensaje({ tipo: 'ok', texto: 'Porcentajes guardados.' });
      setEditandoPorcentajes(false);
      setVersion(version + 1);
    } else {
      setMensaje({ tipo: 'error', texto: r.mensaje });
    }
  }

  // Desactivar (eliminación lógica) con confirmación.
  async function desactivar(beneficiario) {
    if (!window.confirm(`¿Desactivar a ${beneficiario.Nombre}?`)) return;
    const r = await eliminarBeneficiario(beneficiario.IdBeneficiario);
    if (r.ok) {
      setMensaje({ tipo: 'ok', texto: 'Beneficiario desactivado.' });
      revisarSuma.current = true; // al desactivar, revisar la suma
      setVersion(version + 1);
    } else {
      setMensaje({ tipo: 'error', texto: r.mensaje });
    }
  }

  // Abre el formulario de agregar/editar (cierra el editor de porcentajes).
  function abrirFormulario(valor) {
    setMensaje(null);
    setEditandoPorcentajes(false);
    setFormulario(valor);
  }

  // Abre el editor de porcentajes (cierra el formulario).
  function abrirEditorPorcentajes() {
    setMensaje(null);
    setFormulario(null);
    setEditandoPorcentajes(true);
  }

  // Si no hay beneficiarios la suma es 0 y también se muestra la alerta
  // (lectura literal del enunciado; confirmar con el grupo).
  const sumaIncorrecta = resumen !== null && resumen.SumaPorcentajes !== 100;  // check: nombre de columna que devuelve el SP

  return (
    <main className="pagina">
      <header className="encabezado">
        <h1>Beneficiarios de la cuenta {numeroCuenta}</h1>
        <Link to="/cuentas">Volver a mis cuentas</Link>
      </header>

      {/* Rótulo llamativo que pide el enunciado */}
      {sumaIncorrecta && <p className="alerta">{TEXTO_ALERTA}</p>}
      {mensaje && <p className={mensaje.tipo === 'ok' ? 'mensaje-ok' : 'mensaje-error'}>{mensaje.texto}</p>}

      {cargando && <p>Cargando...</p>}
      {!cargando && beneficiarios.length === 0 && <p>No hay beneficiarios activos.</p>}

      {/* O se muestra el editor de porcentajes, o la tabla normal con sus botones */}
      {editandoPorcentajes ? (
        <EditorPorcentajes
          beneficiarios={beneficiarios}
          onGuardar={guardarPorcentajes}
          onCancelar={() => setEditandoPorcentajes(false)}
        />
      ) : (
        <>
          {beneficiarios.length > 0 && (
            <div className="tabla-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Nombre</th>
                    <th>Documento</th>
                    <th>Nacimiento</th>
                    <th>Correo</th>
                    <th>Parentesco</th>
                    <th>Porcentaje</th>
                    <th>Acciones</th>
                  </tr>
                </thead>
                <tbody>
                  {beneficiarios.map((b) => (
                    <tr key={b.IdBeneficiario}> {/* check: nombre de columna que devuelve el SP */}
                      <td>{b.Nombre}</td> {/* check: nombre de columna que devuelve el SP */}
                      <td>{b.ValorDocumentoIdentidad}</td> {/* check: nombre de columna que devuelve el SP */}
                      <td>{b.FechaNacimiento}</td> {/* check: nombre de columna que devuelve el SP */}
                      <td>{b.Email}</td> {/* check: nombre de columna que devuelve el SP */}
                      <td>{b.NombreParentezco}</td> {/* check: nombre de columna que devuelve el SP */}
                      <td>{b.Porcentaje}%</td> {/* check: nombre de columna que devuelve el SP */}
                      <td>
                        <button onClick={() => abrirFormulario(b)}>Editar datos</button>{' '}
                        <button onClick={() => desactivar(b)}>Desactivar</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {resumen && <p>Suma de porcentajes: {resumen.SumaPorcentajes}%</p>} {/* check: nombre de columna que devuelve el SP */}

          {formulario === null && (
            <div className="botones">
              {beneficiarios.length > 0 && (
                <button onClick={abrirEditorPorcentajes}>Editar porcentajes</button>
              )}
              <button onClick={() => abrirFormulario('agregar')}>Agregar beneficiario</button>
            </div>
          )}

          {formulario !== null && (
            <FormularioBeneficiario
              // "key" distinta por beneficiario: obliga a React a crear el
              // formulario de nuevo y arrancar con los datos correctos.
              key={formulario === 'agregar' ? 'agregar' : formulario.IdBeneficiario}
              beneficiario={formulario === 'agregar' ? null : formulario}
              parentezcos={parentezcos}
              tiposDocumento={tiposDocumento}
              onGuardar={guardar}
              onCancelar={() => setFormulario(null)}
            />
          )}
        </>
      )}
    </main>
  );
}