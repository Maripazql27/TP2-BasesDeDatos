
// EDITA LOS PORCENTAJES DE TODOS LOS BENEFICIARIOS A LA VEZ


import { useState } from 'react';

export default function EditorPorcentajes({ beneficiarios, onGuardar, onCancelar }) {
  // "valores" guarda lo que el usuario va escribiendo, como texto, por id:
  //   { 1: '60', 2: '40' }
  const [valores, setValores] = useState(
    Object.fromEntries(beneficiarios.map((b) => [b.IdBeneficiario, String(b.Porcentaje)]))
  );

  // Un texto es válido si es un entero entre 1 y 100 (y no está vacío).
  const esValido = (texto) =>
    texto !== '' && Number.isInteger(Number(texto)) && Number(texto) >= 1 && Number(texto) <= 100;

  // Valores calculados en cada dibujo de la pantalla:
  const todosValidos = beneficiarios.every((b) => esValido(valores[b.IdBeneficiario]));
  const total = beneficiarios.reduce(
    (suma, b) => suma + (esValido(valores[b.IdBeneficiario]) ? Number(valores[b.IdBeneficiario]) : 0),
    0
  );
  const puedeGuardar = todosValidos && total === 100;

  // Actualiza el valor de UN beneficiario sin perder los demás.
  function cambiar(id, texto) {
    setValores({ ...valores, [id]: texto });
  }

  // Entrega la lista completa, con los porcentajes ya convertidos a número.
  function guardar() {
    onGuardar(
      beneficiarios.map((b) => ({
        idBeneficiario: b.IdBeneficiario,
        porcentaje: Number(valores[b.IdBeneficiario]),
      }))
    );
  }

  return (
    <section className="formulario">
      <h2>Editar porcentajes de todos los beneficiarios</h2>
      <table>
        <thead>
          <tr>
            <th>Nombre</th>
            <th>Parentesco</th>
            <th>Porcentaje</th>
          </tr>
        </thead>
        <tbody>
          {beneficiarios.map((b) => (
            <tr key={b.IdBeneficiario}>
              <td>{b.Nombre}</td>
              <td>{b.NombreParentezco}</td>
              <td>
                <input
                  className="entrada-porcentaje"
                  type="number"
                  min={1}
                  max={100}
                  step={1}
                  value={valores[b.IdBeneficiario]}
                  onChange={(e) => cambiar(b.IdBeneficiario, e.target.value)}
                />
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {/* Total en vivo: verde si es 100, rojo si no */}
      <p className={puedeGuardar ? 'mensaje-ok' : 'mensaje-error'}>
        Total: {total}% {puedeGuardar ? '' : '(debe sumar exactamente 100)'}
      </p>

      <div className="botones">
        <button onClick={guardar} disabled={!puedeGuardar}>Guardar porcentajes</button>
        <button onClick={onCancelar}>Cancelar</button>
      </div>
    </section>
  );
}