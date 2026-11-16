// Pruebas de contrato de la exposición de precios al mecánico (Sprint 5, US5,
// FR-025, FR-026, FR-034 a FR-036): el mecánico no recibe precios de
// refacciones ni totales por ninguna vía; sí recibe el precio de la mano de
// obra (alcance de D-10).
// Fuente de verdad: specs/005-precios-refacciones-cobro/contracts/.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';

let ctx;
let ordenId;

const CLAVES_DE_PRECIO_DE_REFACCION = ['precioUnitario', 'importe', 'aviso'];

function sinPreciosDeRefaccion(cuerpo) {
  for (const linea of cuerpo.repuestos ?? []) {
    for (const clave of CLAVES_DE_PRECIO_DE_REFACCION) {
      expect(linea).not.toHaveProperty(clave);
    }
  }
  expect(cuerpo).not.toHaveProperty('total');
  expect(cuerpo).not.toHaveProperty('subtotalRefacciones');
}

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Exposición al mecánico');
  ordenId = await ctx.crearOrden({ asignarMecanico: true });
  expect((await ctx.agregarServicio(ordenId, 450, ctx.tokens.mecanico)).status).toBe(201);
  const partId = await ctx.crearRefaccion({ precioVenta: 320, precioCompra: 180 });
  expect((await ctx.agregarRefaccion(ordenId, partId, 2, ctx.tokens.mecanico)).status).toBe(201);
});

describe('FR-035: pagos, tickets y panel responden 403 al mecánico', () => {
  test.each([
    ['get', () => `/api/payments/orden/${ordenId}`],
    ['get', () => `/api/payments/orden/${ordenId}/total`],
    ['post', () => '/api/payments'],
    ['get', () => `/api/tickets/orden/${ordenId}`],
    ['post', () => '/api/tickets'],
    ['get', () => '/api/dashboard'],
  ])('%s_%s', async (metodo, ruta) => {
    const r = await api[metodo](ruta()).set(bearer(ctx.tokens.mecanico)).send({ ordenId });
    expect(r.status).toBe(403);
  });
});

test('FR_034_el_detalle_y_el_listado_no_traen_totales_ni_precios_de_refaccion', async () => {
  const detalle = await api
    .get(`/api/service-orders/${ordenId}`)
    .set(bearer(ctx.tokens.mecanico));
  expect(detalle.status).toBe(200);
  sinPreciosDeRefaccion(detalle.body);

  const listado = await api.get('/api/service-orders').set(bearer(ctx.tokens.mecanico));
  expect(listado.status).toBe(200);
  for (const orden of listado.body.elementos) sinPreciosDeRefaccion(orden);
});

test('FR_026_el_mecanico_si_recibe_el_precio_de_la_mano_de_obra', async () => {
  const detalle = await api
    .get(`/api/service-orders/${ordenId}`)
    .set(bearer(ctx.tokens.mecanico));
  expect(Number(detalle.body.servicios[0].manoDeObra.precio)).toBe(450);
});

test('FR_036_TOTAL_EXCEDE_LIMITE_para_el_mecanico_no_trae_cifras', async () => {
  const orden = await ctx.crearOrden({ asignarMecanico: true });
  // Una mano de obra de prueba en el máximo de DECIMAL(10,2): 99,999,999.99.
  const servicio = await sql(
    "INSERT INTO order_services (service_order_id, description) VALUES (?, 'Tope')",
    [orden],
  );
  await sql(
    `INSERT INTO order_labor (service_order_id, service_id, description, duration_minutes, price)
     VALUES (?, ?, 'Tope', 10, 99999999.99)`,
    [orden, servicio.insertId],
  );
  const r = await ctx.agregarServicio(orden, 1, ctx.tokens.mecanico);
  expect(r.status).toBe(409);
  expect(r.body.error.codigo).toBe('TOTAL_EXCEDE_LIMITE');
  expect(r.body.error.mensaje).not.toMatch(/\d/);

  // Para el administrador el mensaje sí incluye el tope.
  const admin = await ctx.agregarServicio(orden, 1, ctx.tokens.admin);
  expect(admin.body.error.mensaje).toContain('99,999,999.99');
});

test('FR_036_los_demas_errores_que_recibe_el_mecanico_no_traen_cifras_de_precio', async () => {
  const sinPrecio = await ctx.crearRefaccion({ precioVenta: null });
  const r = await ctx.agregarRefaccion(ordenId, sinPrecio, 1, ctx.tokens.mecanico);
  expect(r.status).toBe(409);
  expect(r.body.error.codigo).toBe('REFACCION_SIN_PRECIO');
  expect(r.body.error.mensaje).not.toMatch(/\d/);
});

describe('FR-025 / FR-034: ninguna respuesta armada con toApiDetail trae precios de refacción al mecánico', () => {
  test('cambio_de_estado', async () => {
    const r = await api
      .post(`/api/service-orders/${ordenId}/estado`)
      .set(bearer(ctx.tokens.mecanico))
      .send({ estado: 'DIAGNOSTICO' });
    expect(r.status).toBe(200);
    expect(r.body.repuestos.length).toBeGreaterThan(0);
    sinPreciosDeRefaccion(r.body);
  });

  test('detalle_y_listado_del_mecanico_tras_agregar_refacciones', async () => {
    // El alta y la edición de la orden (que también usan toApiDetail) son
    // solo de ADMIN y RECEPTIONIST: el mecánico recibe 403 sin cuerpo de orden.
    const [orden] = await sql('SELECT entry_mileage FROM service_orders WHERE id = ?', [ordenId]);
    const edicion = await api
      .put(`/api/service-orders/${ordenId}`)
      .set(bearer(ctx.tokens.mecanico))
      .send({
        motivoVisita: 'Edición del mecánico',
        fechaIngreso: '2026-11-16',
        kilometraje: orden.entry_mileage,
      });
    expect(edicion.status).toBe(403);
    expect(edicion.body).not.toHaveProperty('repuestos');

    const detalle = await api
      .get(`/api/service-orders/${ordenId}`)
      .set(bearer(ctx.tokens.mecanico));
    sinPreciosDeRefaccion(detalle.body);
  });

  test('diagnostico_recomendaciones_y_alta_y_baja_de_servicios_no_devuelven_precios_de_refaccion', async () => {
    const diagnostico = await api
      .post(`/api/service-orders/${ordenId}/diagnostico`)
      .set(bearer(ctx.tokens.mecanico))
      .send({ texto: 'Revisión completa' });
    const recomendaciones = await api
      .post(`/api/service-orders/${ordenId}/recomendaciones`)
      .set(bearer(ctx.tokens.mecanico))
      .send({ texto: 'Volver en 6 meses' });
    const alta = await ctx.agregarServicio(ordenId, 50, ctx.tokens.mecanico);
    const baja = await api
      .delete(`/api/service-orders/${ordenId}/servicios/${alta.body.servicio.id}`)
      .set(bearer(ctx.tokens.mecanico));

    for (const r of [diagnostico, recomendaciones, alta, baja]) {
      expect(r.status).toBeLessThan(300);
      const texto = JSON.stringify(r.body);
      for (const clave of CLAVES_DE_PRECIO_DE_REFACCION) {
        expect(texto).not.toContain(`"${clave}"`);
      }
    }
  });

  test('el_mismo_detalle_si_trae_precios_para_recepcion_comprobando_que_existen', async () => {
    const r = await api
      .get(`/api/service-orders/${ordenId}`)
      .set(bearer(ctx.tokens.recepcion));
    expect(r.body.repuestos[0]).toHaveProperty('precioUnitario', 320);
  });
});
