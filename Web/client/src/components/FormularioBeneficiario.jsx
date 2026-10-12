// FORMULARIO PARA AGREGAR O EDITAR UN BENEFICIARIO

import { useState } from 'react';

export default function FormularioBeneficiario({
  beneficiario,
  parentezcos,
  tiposDocumento,
  otros = [], // beneficiarios activos actuales (solo se usa al AGREGAR, para hacerles espacio)
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

  // Al AGREGAR, la suma de todos los porcentajes no puede pasar de 100 (lo exige el SP).
  // Si los beneficiarios actuales ya suman 100, el usuario baja aquí los porcentajes de
  // ellos para dejar espacio al nuevo. Se guardan como texto, por id: { 7: '50', 8: '50' }.
  const [ajustes, setAjustes] = useState(
    Object.fromEntries(otros.map((b) => [b.IdBeneficiario, String(b.Porcentaje)]))
  );
  const esPorcentaje = (texto) =>
    texto !== '' && Number.isInteger(Number(texto)) && Number(texto) >= 1 && Number(texto) <= 100;
  const ajustesValidos = otros.every((b) => esPorcentaje(ajustes[b.IdBeneficiario]));
  const totalOtros = otros.reduce((suma, b) => suma + (esPorcentaje(ajustes[b.IdBeneficiario]) ? Number(ajustes[b.IdBeneficiario]) : 0), 0);
  const totalConNuevo = totalOtros + (Number.isInteger(Number(datos.porcentaje)) ? Number(datos.porcentaje) : 0);
  const sumaPasa100 = !editando && totalConNuevo > 100;

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
      // Al AGREGAR: porcentajes (nuevos o iguales) de los beneficiarios actuales, para hacerles espacio.
      ...(editando
        ? {}
        : { ajustes: otros.map((b) => ({ idBeneficiario: b.IdBeneficiario, porcentaje: Number(ajustes[b.IdBeneficiario]) })) }),
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
              onChange={cambiar} maxLength={128} required
              pattern=".+@.+\..+" title="Debe tener la forma nombre@dominio.com" />
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

      {/* Solo al AGREGAR y si ya hay beneficiarios: permite bajar sus porcentajes para dejar espacio */}
      {!editando && otros.length > 0 && (
        <fieldset>
          <legend>Porcentajes de los beneficiarios actuales</legend>
          <p>La suma de todos no puede pasar de 100. Si ya suman 100, baje alguno para dejar espacio al nuevo.</p>
          {otros.map((b) => (
            <label key={b.IdBeneficiario}>
              {b.Nombre} ({b.NombreParentezco})
              <input className="entrada-porcentaje" type="number" min={1} max={100} step={1}
                value={ajustes[b.IdBeneficiario]}
                onChange={(e) => setAjustes({ ...ajustes, [b.IdBeneficiario]: e.target.value })} />
            </label>
          ))}
          <p className={sumaPasa100 ? 'mensaje-error' : 'mensaje-ok'}>
            Total con el nuevo: {totalConNuevo}% {sumaPasa100 && '(no puede superar 100)'}
          </p>
        </fieldset>
      )}

      <div className="botones">
        <button type="submit" disabled={sumaPasa100 || !ajustesValidos}>Guardar</button>
        <button type="button" onClick={onCancelar}>Cancelar</button>
      </div>
    </form>
  );
}