
// FORMULARIO PARA AGREGAR O EDITAR UN BENEFICIARIO

import { useState } from 'react';

export default function FormularioBeneficiario({
  beneficiario,
  parentezcos,
  tiposDocumento,
  onGuardar,
  onCancelar,
}) {
  const editando = Boolean(beneficiario);

  // Todos los campos en un solo objeto de estado. Si se edita, algunos campos
  // arrancan con el valor actual del beneficiario.
  const [datos, setDatos] = useState({
    idTipoDocuIdentidad: tiposDocumento[0]?.Id ?? '',
    valorDocumentoIdentidad: '',
    nombre: beneficiario?.Nombre ?? '',
    fechaNacimiento: '',
    email: '',
    telefono1: '',
    telefono2: '',
    idParentezco: beneficiario?.IdParentezco ?? parentezcos[0]?.Id ?? '',
    porcentaje: beneficiario?.Porcentaje ?? '',
  });

  // Un solo manejador para todos los campos: usa el atributo "name" del
  // campo para saber cuál propiedad del estado actualizar.
  function cambiar(evento) {
    setDatos({ ...datos, [evento.target.name]: evento.target.value });
  }

  // Al enviar: los campos numéricos se convierten de texto a número.
  function enviar(evento) {
    evento.preventDefault();
    onGuardar({
      ...datos,
      idTipoDocuIdentidad: Number(datos.idTipoDocuIdentidad),
      idParentezco: Number(datos.idParentezco),
      porcentaje: Number(datos.porcentaje),
    });
  }

  return (
    <form className="formulario" onSubmit={enviar}>
      <h2>{editando ? 'Editar beneficiario' : 'Agregar beneficiario'}</h2>

      {/* Documento: solo se pide al AGREGAR (al editar no se puede cambiar) */}
      {!editando && (
        <>
          <label>
            Tipo de documento
            <select name="idTipoDocuIdentidad" value={datos.idTipoDocuIdentidad} onChange={cambiar}>
              {tiposDocumento.map((t) => (
                <option key={t.Id} value={t.Id}>{t.Nombre}</option>
              ))}
            </select>
          </label>
          <label>
            Número de documento
            <input name="valorDocumentoIdentidad" value={datos.valorDocumentoIdentidad}
              onChange={cambiar} maxLength={32} pattern="[0-9]+"
              title="Solo números" required />
          </label>
        </>
      )}

      <label>
        Nombre
        <input name="nombre" value={datos.nombre} onChange={cambiar} maxLength={64} required />
      </label>

      {/* Datos personales: solo al AGREGAR. Se piden 2 teléfonos (el PDF exige al menos 2) */}
      {!editando && (
        <>
          <label>
            Fecha de nacimiento
            <input type="date" name="fechaNacimiento" value={datos.fechaNacimiento}
              onChange={cambiar} required />
          </label>
          <label>
            Correo electrónico
            <input type="email" name="email" value={datos.email}
              onChange={cambiar} maxLength={128} required />
          </label>
          <label>
            Teléfono 1
            <input name="telefono1" value={datos.telefono1} onChange={cambiar}
              maxLength={16} pattern="[0-9]+" title="Solo números" required />
          </label>
          <label>
            Teléfono 2
            <input name="telefono2" value={datos.telefono2} onChange={cambiar}
              maxLength={16} pattern="[0-9]+" title="Solo números" required />
          </label>
        </>
      )}

      <label>
        Parentesco
        <select name="idParentezco" value={datos.idParentezco} onChange={cambiar}>
          {parentezcos.map((p) => (
            <option key={p.Id} value={p.Id}>{p.Nombre}</option>
          ))}
        </select>
      </label>

      {/* Porcentaje: solo al AGREGAR. Después se cambia junto con los demás */}
      {!editando && (
        <label>
          Porcentaje (1 a 100)
          <input type="number" name="porcentaje" value={datos.porcentaje}
            onChange={cambiar} min={1} max={100} step={1} required />
        </label>
      )}

      <div className="botones">
        <button type="submit">Guardar</button>
        <button type="button" onClick={onCancelar}>Cancelar</button>
      </div>
    </form>
  );
}