// Pruebas unitarias del rango de los reportes (Sprint 7, Entrega B, FR-031).
import { parseReportRange, MAX_REPORT_DAYS } from '../../utils/report-range.js';

function codigoDe(fn) {
  try {
    fn();
  } catch (error) {
    return { status: error.status, code: error.code, message: error.message };
  }
  return null;
}

test('test_acepta_un_rango_valido_y_cuenta_los_dias_con_ambos_extremos', () => {
  expect(parseReportRange({ desde: '2026-11-01', hasta: '2026-11-30' })).toEqual({
    desde: '2026-11-01',
    hasta: '2026-11-30',
    dias: 30,
  });
  expect(parseReportRange({ desde: '2026-11-26', hasta: '2026-11-26' }).dias).toBe(1);
});

test('test_acepta_hasta_366_dias_en_un_anio_bisiesto', () => {
  expect(MAX_REPORT_DAYS).toBe(366);
  expect(parseReportRange({ desde: '2028-01-01', hasta: '2028-12-31' }).dias).toBe(366);
});

test.each([
  ['sin fechas', {}],
  ['sin hasta', { desde: '2026-11-01' }],
  ['formato incorrecto', { desde: '01/11/2026', hasta: '2026-11-30' }],
  ['fecha inexistente', { desde: '2026-02-30', hasta: '2026-03-01' }],
  ['inicio posterior al fin', { desde: '2026-12-01', hasta: '2026-11-01' }],
  ['más de 366 días', { desde: '2025-01-01', hasta: '2026-01-02' }],
])('test_rechaza_%s_con_400_rango_invalido', (_caso, rango) => {
  const error = codigoDe(() => parseReportRange(rango));
  expect(error).toMatchObject({ status: 400, code: 'RANGO_INVALIDO' });
  expect(error.message.length).toBeGreaterThan(10);
});
