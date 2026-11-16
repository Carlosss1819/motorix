// Prueba unitaria del cuerpo de la preferencia de Mercado Pago (Sprint 5,
// FR-037, SC-014, R-09): vencimiento con `expires`, `expiration_date_from` y
// `expiration_date_to` en ISO 8601 con zona horaria, y el `unit_price` igual
// al total con precio congelado (FR-015). Función pura: sin red.
import { armarPreferencia, fechaIsoConZona } from '../../services/payment_gateway/mercadopago.js';
import { calcularTotal } from '../../utils/order-total.js';

const ISO_CON_ZONA = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}[+-]\d{2}:\d{2}$/;
const AHORA = new Date('2026-11-16T18:30:00.000Z');

function cuerpo(extra = {}) {
  return armarPreferencia({
    orden: { id: 42 },
    monto: 1390,
    referencia: 'MOT-42-1',
    ahora: AHORA,
    vigenciaHoras: 24,
    urlPublica: 'http://localhost:3000',
    ...extra,
  });
}

test('la_preferencia_vence_con_expires_true', () => {
  expect(cuerpo().expires).toBe(true);
});

test('expiration_date_from_es_ahora_y_to_es_ahora_mas_24_horas', () => {
  const { expiration_date_from: desde, expiration_date_to: hasta } = cuerpo();
  expect(new Date(desde).getTime()).toBe(AHORA.getTime());
  expect(new Date(hasta).getTime() - new Date(desde).getTime()).toBe(24 * 60 * 60 * 1000);
});

test('la_vigencia_es_configurable', () => {
  const { expiration_date_from: desde, expiration_date_to: hasta } = cuerpo({ vigenciaHoras: 2 });
  expect(new Date(hasta).getTime() - new Date(desde).getTime()).toBe(2 * 60 * 60 * 1000);
});

test('las_dos_fechas_van_en_ISO_8601_con_zona_horaria', () => {
  const { expiration_date_from: desde, expiration_date_to: hasta } = cuerpo();
  expect(desde).toMatch(ISO_CON_ZONA);
  expect(hasta).toMatch(ISO_CON_ZONA);
  expect(fechaIsoConZona(AHORA)).toMatch(ISO_CON_ZONA);
});

test('el_unit_price_es_el_total_con_precio_congelado_aunque_cambie_el_catalogo', () => {
  // La línea guarda 320.00 al agregarse; después el catálogo subió a 500.00,
  // pero el contenido de cobro trae el precio congelado de la línea.
  const total = calcularTotal({
    manoDeObra: [{ id: 1, descripcion: 'Frenos', precio: '750.00' }],
    refacciones: [{ id: 1, descripcion: 'Pastillas', cantidad: 2, partId: 3, precioUnitario: '320.00' }],
  });
  const { items } = cuerpo({ monto: total.total });
  expect(items).toHaveLength(1);
  expect(items[0].unit_price).toBe(1390);
  expect(items[0].currency_id).toBe('MXN');
  expect(items[0].quantity).toBe(1);
});

test('conserva_la_referencia_externa_y_las_urls_de_regreso', () => {
  const preferencia = cuerpo();
  expect(preferencia.external_reference).toBe('MOT-42-1');
  expect(preferencia.back_urls.success).toBe('http://localhost:3000');
  expect(preferencia.metadata).toEqual({ ordenId: 42 });
});
