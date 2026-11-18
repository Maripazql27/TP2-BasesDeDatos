// =============================================================================
// Un solo lugar para que todas las pantallas muestren los montos igual:
//   594249.01  -> "₡ 594 249,01"      (formato de Costa Rica)
//   -45.5      -> "-$ 45,50"          (el signo va ANTES del símbolo)
// Si el SP no devuelve el símbolo de la moneda, se muestra solo el número.
// =============================================================================
const formatoNumero = new Intl.NumberFormat('es-CR', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export function dinero(simbolo, valor) {
  const numero = Number(valor);
  const signo = numero < 0 ? '-' : '';
  const texto = formatoNumero.format(Math.abs(numero));
  // espacio sin salto entre el símbolo y el número: el monto nunca se parte en dos líneas
  return `${signo}${simbolo ? `${simbolo}\u00A0` : ''}${texto}`;
}