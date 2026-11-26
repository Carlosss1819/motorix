// Exportación CSV de los reportes (Sprint 7, Entrega B, FR-037, R-08), sin
// librerías: UTF-8 con BOM (para que la hoja de cálculo lea acentos y eñes),
// separador coma, fin de línea CRLF y comillas dobles para los campos con
// coma, comillas o saltos de línea (las comillas internas se duplican).
//
// Protección contra fórmulas: un texto que empieza con = + - @ (o tabulador
// o retorno) se antepone con un apóstrofo para que la hoja de cálculo no lo
// ejecute como fórmula. Los números nunca se alteran.

export const CSV_BOM = '\uFEFF';
const CRLF = '\r\n';
const INICIO_FORMULA = /^[=+\-@\t\r]/;

export function escapeCsvValue(value) {
  if (value === null || value === undefined) return '';
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : '';
  let texto = String(value);
  if (INICIO_FORMULA.test(texto)) texto = `'${texto}`;
  if (/[",\r\n]/.test(texto)) return `"${texto.replace(/"/g, '""')}"`;
  return texto;
}

// Importe en número → cadena con dos decimales ('1234.50'); `null` → vacío.
export function csvMoney(value) {
  if (value === null || value === undefined) return '';
  return Number(value).toFixed(2);
}

// `headers`: lista de títulos; `rows`: lista de arreglos con el mismo orden.
export function toCsv(headers, rows) {
  const lineas = [headers, ...rows].map((fila) => fila.map(escapeCsvValue).join(','));
  return `${CSV_BOM}${lineas.join(CRLF)}${CRLF}`;
}
