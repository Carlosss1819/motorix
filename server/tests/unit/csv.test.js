// Pruebas unitarias del CSV de los reportes (Sprint 7, Entrega B, FR-037).
import { toCsv, escapeCsvValue, csvMoney, CSV_BOM } from '../../utils/csv.js';

test('test_el_csv_empieza_con_bom_usa_coma_y_termina_cada_linea_con_crlf', () => {
  const csv = toCsv(['metodo', 'total'], [['EFECTIVO', '100.00'], ['TARJETA', '50.50']]);
  expect(csv.startsWith(CSV_BOM)).toBe(true);
  expect(csv).toBe('\uFEFFmetodo,total\r\nEFECTIVO,100.00\r\nTARJETA,50.50\r\n');
});

test('test_conserva_acentos_y_enies', () => {
  expect(toCsv(['nombre'], [['Afinación de motor con piñón']])).toContain('Afinación de motor con piñón');
});

test('test_entrecomilla_comas_comillas_y_saltos_de_linea_duplicando_las_comillas', () => {
  expect(escapeCsvValue('Balata, delantera')).toBe('"Balata, delantera"');
  expect(escapeCsvValue('Llanta 15" Michelin')).toBe('"Llanta 15"" Michelin"');
  expect(escapeCsvValue('línea 1\nlínea 2')).toBe('"línea 1\nlínea 2"');
});

test('test_valores_vacios_y_numeros', () => {
  expect(escapeCsvValue(null)).toBe('');
  expect(escapeCsvValue(undefined)).toBe('');
  expect(escapeCsvValue(-12.5)).toBe('-12.5');
  expect(csvMoney(1234.5)).toBe('1234.50');
  expect(csvMoney(null)).toBe('');
});

test('test_neutraliza_textos_que_parecen_formulas', () => {
  expect(escapeCsvValue('=HYPERLINK("x")')).toBe('"\'=HYPERLINK(""x"")"');
  expect(escapeCsvValue('+5')).toBe("'+5");
  expect(escapeCsvValue('@SUMA')).toBe("'@SUMA");
});
