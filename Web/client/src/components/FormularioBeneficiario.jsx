import { useState } from 'react';

// Sirve para agregar (beneficiario = null) y para editar.
// Al editar solo se pueden cambiar nombre, parentesco y porcentaje.
export default function FormularioBeneficiario({
  beneficiario,
  parentezcos,
  tiposDocumento,
  onGuardar,
  onCancelar,
}) {
  const editando = Boolean(beneficiario);
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

  function cambiar(evento) {
    setDatos({ ...datos, [evento.target.name]: evento.target.value });
  }

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
         {!editando && (
        <label>
          Porcentaje (0 a 100)
          <input type="number" name="porcentaje" value={datos.porcentaje}
            onChange={cambiar} min={0} max={100} step={1} required />
        </label>
      )}

      <div className="botones">
        <button type="submit">Guardar</button>
        <button type="button" onClick={onCancelar}>Cancelar</button>
      </div>
    </form>
  );
}