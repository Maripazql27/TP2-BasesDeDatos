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
  const { numeroCuenta } = useParams();
  const [beneficiarios, setBeneficiarios] = useState([]);
  const [resumen, setResumen] = useState(null);
  const [parentezcos, setParentezcos] = useState([]);
  const [tiposDocumento, setTiposDocumento] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [mensaje, setMensaje] = useState(null); // { tipo: 'ok' | 'error', texto }
  const [formulario, setFormulario] = useState(null); // null | 'agregar' | beneficiario
  const [editandoPorcentajes, setEditandoPorcentajes] = useState(false);
  const [version, setVersion] = useState(0); // al cambiar, se vuelve a consultar
  // Después de agregar o desactivar se revisa la suma y, si no es 100,
  // se abre el editor de porcentajes para corregirla.
  const revisarSuma = useRef(false);

  // Catálogos para los desplegables (una sola vez).
  useEffect(() => {
    async function cargarCatalogos() {
      const p = await listarParentezcos();
      const t = await listarTiposDocumento();
      if (p.ok) setParentezcos(p.datos);
      if (t.ok) setTiposDocumento(t.datos);
    }
    cargarCatalogos();
  }, []);

  // Lista de beneficiarios y suma de porcentajes.
  useEffect(() => {
    async function cargar() {
      const r = await listarBeneficiarios(numeroCuenta);
      if (r.ok) {
        setBeneficiarios(r.beneficiarios);
        setResumen(r.resumen);
        if (revisarSuma.current) {
          revisarSuma.current = false;
          if (r.resumen.CantidadBeneficiarios > 0 && r.resumen.SumaPorcentajes !== 100) {
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
      revisarSuma.current = !esEdicion;
      setVersion(version + 1);
    } else {
      setMensaje({ tipo: 'error', texto: r.mensaje });
    }
  }

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

  async function desactivar(beneficiario) {
    if (!window.confirm(`¿Desactivar a ${beneficiario.Nombre}?`)) return;
    const r = await eliminarBeneficiario(beneficiario.IdBeneficiario);
    if (r.ok) {
      setMensaje({ tipo: 'ok', texto: 'Beneficiario desactivado.' });
      revisarSuma.current = true;
      setVersion(version + 1);
    } else {
      setMensaje({ tipo: 'error', texto: r.mensaje });
    }
  }

  function abrirFormulario(valor) {
    setMensaje(null);
    setEditandoPorcentajes(false);
    setFormulario(valor);
  }

  function abrirEditorPorcentajes() {
    setMensaje(null);
    setFormulario(null);
    setEditandoPorcentajes(true);
  }

  // Si no hay beneficiarios la suma es 0 y también se muestra la alerta
  // (lectura literal del enunciado; confirmar con el grupo).
  const sumaIncorrecta = resumen !== null && resumen.SumaPorcentajes !== 100;

  return (
    <main className="pagina">
      <header className="encabezado">
        <h1>Beneficiarios de la cuenta {numeroCuenta}</h1>
        <Link to="/cuentas">Volver a mis cuentas</Link>
      </header>

      {sumaIncorrecta && <p className="alerta">{TEXTO_ALERTA}</p>}
      {mensaje && <p className={mensaje.tipo === 'ok' ? 'mensaje-ok' : 'mensaje-error'}>{mensaje.texto}</p>}

      {cargando && <p>Cargando...</p>}
      {!cargando && beneficiarios.length === 0 && <p>No hay beneficiarios activos.</p>}

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
                    <tr key={b.IdBeneficiario}>
                      <td>{b.Nombre}</td>
                      <td>{b.ValorDocumentoIdentidad}</td>
                      <td>{b.FechaNacimiento}</td>
                      <td>{b.Email}</td>
                      <td>{b.NombreParentezco}</td>
                      <td>{b.Porcentaje}%</td>
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

          {resumen && <p>Suma de porcentajes: {resumen.SumaPorcentajes}%</p>}

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