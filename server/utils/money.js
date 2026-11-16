// Conversión monetaria del Sprint 5 (R-06, D-08): los importes se guardan como
// DECIMAL(10,2) y mysql2 los entrega como cadena ('320.00'). Aquí se pasan a
// centavos enteros SIN pasar por flotante (se separan la parte entera y la
// decimal de la cadena), se suman como enteros y solo al responder se
// convierten a número de dos decimales.

const PATRON_IMPORTE = /^(-)?(\d+)(?:\.(\d+))?$/;

// Cadena DECIMAL o número → centavos enteros. `null`/`undefined` → `null`.
// Con más de dos decimales se redondea al centavo hacia arriba desde 0.5.
export function toCents(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new TypeError(`Importe no válido: ${value}`);
    // Un número con hasta dos decimales queda a menos de 1e-6 de un entero al
    // multiplicarlo por 100, así que el redondeo es exacto.
    return Math.round(value * 100);
  }
  const texto = String(value).trim();
  const partes = PATRON_IMPORTE.exec(texto);
  if (!partes) throw new TypeError(`Importe no válido: ${texto}`);
  const [, signo, enteros, decimales = ''] = partes;
  const dosDecimales = `${decimales}00`.slice(0, 2);
  let centavos = Number(enteros) * 100 + Number(dosDecimales);
  if (decimales.length > 2 && Number(decimales[2]) >= 5) centavos += 1;
  return signo ? -centavos : centavos;
}

// Centavos enteros → número de dos decimales para las respuestas JSON.
export function fromCents(cents) {
  if (cents === null || cents === undefined) return null;
  return cents / 100;
}

// Centavos enteros → cadena 'NNN.NN' para guardar en una columna DECIMAL.
export function centsToDecimalString(cents) {
  const negativo = cents < 0;
  const absoluto = Math.abs(cents);
  const enteros = Math.floor(absoluto / 100);
  const decimales = String(absoluto % 100).padStart(2, '0');
  return `${negativo ? '-' : ''}${enteros}.${decimales}`;
}
