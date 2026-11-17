// Prueba unitaria del criterio de orden detenida (Sprint 6, FR-006, R-04):
// estados no finales (sin TERMINADO ni ENTREGADO) y más de N × 24 horas sin
// cambio de estado. Reloj fijo: no depende de la hora de la corrida (M3).
import { isStalled, STALLED_ORDER_STATUSES } from '../../utils/stalled-order.js';

const AHORA = new Date('2026-11-16T12:00:00');
const horasAntes = (horas) => new Date(AHORA.getTime() - horas * 60 * 60 * 1000);

test('los_estados_no_finales_son_exactamente_cuatro', () => {
  expect([...STALLED_ORDER_STATUSES]).toEqual([
    'RECIBIDO',
    'DIAGNOSTICO',
    'EN_REPARACION',
    'ESPERANDO_REFACCION',
  ]);
});

test.each(['RECIBIDO', 'DIAGNOSTICO', 'EN_REPARACION', 'ESPERANDO_REFACCION'])(
  'una_orden_%s_con_mas_de_N_dias_sin_cambio_esta_detenida',
  (status) => {
    expect(isStalled({ status, reference: horasAntes(73), now: AHORA, days: 3 })).toBe(true);
  },
);

test('justo_en_el_limite_de_N_por_24_horas_no_esta_detenida', () => {
  expect(
    isStalled({ status: 'DIAGNOSTICO', reference: horasAntes(72), now: AHORA, days: 3 }),
  ).toBe(false);
});

test.each(['TERMINADO', 'ENTREGADO'])('una_orden_%s_nunca_esta_detenida', (status) => {
  expect(isStalled({ status, reference: horasAntes(500), now: AHORA, days: 3 })).toBe(false);
});

test('respeta_un_N_distinto', () => {
  expect(isStalled({ status: 'RECIBIDO', reference: horasAntes(30), now: AHORA, days: 1 })).toBe(
    true,
  );
  expect(isStalled({ status: 'RECIBIDO', reference: horasAntes(30), now: AHORA, days: 2 })).toBe(
    false,
  );
});

test('una_referencia_en_el_futuro_no_esta_detenida', () => {
  expect(isStalled({ status: 'RECIBIDO', reference: horasAntes(-5), now: AHORA, days: 3 })).toBe(
    false,
  );
});
