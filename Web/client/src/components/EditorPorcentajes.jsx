import { useState } from 'react';

// Edita los porcentajes de TODOS los beneficiarios activos a la vez.
// Solo permite guardar cuando el total es exactamente 100
// (la base de datos vuelve a validarlo).
export default function EditorPorcentajes({ beneficiarios, onGuardar, onCancelar }) {
  const [valores, setValores] = useState(
    Object.fromEntries(beneficiarios.map((b) => [b.IdBeneficiario, String(b.Porcentaje)]))
  );

  const esValido = (texto) =>
    texto !== '' && Number.isInteger(Number(texto)) && Number(texto) >= 0 && Number(texto) <= 100;

  const todosValidos = beneficiarios.every((b) => esValido(valores[b.IdBeneficiario]));
  const total = beneficiarios.reduce(
    (suma, b) => suma + (esValido(valores[b.IdBeneficiario]) ? Number(valores[b.IdBeneficiario]) : 0),
    0
  );
  const puedeGuardar = todosValidos && total === 100;

  function cambiar(id, texto) {
    setValores({ ...valores, [id]: texto });
  }

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
                  min={0}
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