// Pruebas de integración del precio congelado (Sprint 5, US2): la línea de
// refacción guarda el precio de venta vigente al agregarla (FR-006) y ni el
// catálogo ni la desactivación la cambian (FR-007, SC-001); quitarla y
// volver a agregarla toma el precio nuevo (FR-011); sin precio no se agrega
// (FR-005); el total tiene tope (FR-008) y es exacto al centavo.
// Fuente de verdad: specs/005-precios-refacciones-cobro/contracts/service-orders.md.
import { api, bearer } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';

let ctx;

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Precio congelado');
});

test('addPart_guarda_unit_price_con_el_precio_vigente_FR_006', async () => {
  const ordenId = await ctx.crearOrden();
  const partId = await ctx.crearRefaccion({ precioVenta: 320 });
  const r = await ctx.agregarRefaccion(ordenId, partId, 2);
  expect(r.status).toBe(201);

  const [linea] = await sql('SELECT unit_price FROM order_parts WHERE id = ?', [r.body.id]);
  expect(linea.unit_price).toBe('320.00');
});

test('cambiar_el_precio_del_catalogo_o_desactivar_no_cambia_la_linea_ni_el_total_FR_007_SC_001', async () => {
  const ordenId = await ctx.crearOrden();
  await ctx.agregarServicio(ordenId, 750);
  const partId = await ctx.crearRefaccion({ precioVenta: 320 });
  expect((await ctx.agregarRefaccion(ordenId, partId, 2)).status).toBe(201);

  const antes = await ctx.total(ordenId);
  expect(antes.total).toBe(1390);

  expect((await ctx.cambiarPrecioVenta(partId, 500)).status).toBe(200);
  const despuesDelCambio = await ctx.total(ordenId);
  expect(despuesDelCambio.total).toBe(1390);
  expect(despuesDelCambio.desglose.refacciones[0].precioUnitario).toBe(320);

  const baja = await api
    .post(`/api/parts/${partId}/desactivar`)
    .set(bearer(ctx.tokens.admin));
  expect(baja.status).toBe(200);
  expect((await ctx.total(ordenId)).total).toBe(1390);

  const detalle = await api
    .get(`/api/service-orders/${ordenId}`)
    .set(bearer(ctx.tokens.admin));
  expect(detalle.body.repuestos[0].precioUnitario).toBe(320);
  expect(detalle.body.repuestos[0].importe).toBe(640);
});

test('quitar_y_volver_a_agregar_la_linea_toma_el_precio_nuevo_FR_011', async () => {
  const ordenId = await ctx.crearOrden();
  const partId = await ctx.crearRefaccion({ precioVenta: 100 });
  const primera = await ctx.agregarRefaccion(ordenId, partId, 1);
  expect(primera.status).toBe(201);

  await ctx.cambiarPrecioVenta(partId, 125.5);
  const baja = await api
    .delete(`/api/service-orders/${ordenId}/refacciones/${primera.body.id}`)
    .set(bearer(ctx.tokens.admin));
  expect(baja.status).toBe(200);
  expect((await ctx.agregarRefaccion(ordenId, partId, 1)).status).toBe(201);

  expect((await ctx.total(ordenId)).total).toBe(125.5);
});

test('una_refaccion_sin_precio_de_venta_da_409_REFACCION_SIN_PRECIO_FR_005', async () => {
  const ordenId = await ctx.crearOrden();
  const partId = await ctx.crearRefaccion({ precioVenta: null });
  const [antes] = await sql('SELECT stock_current FROM parts WHERE id = ?', [partId]);

  const r = await ctx.agregarRefaccion(ordenId, partId, 1);
  expect(r.status).toBe(409);
  expect(r.body.error.codigo).toBe('REFACCION_SIN_PRECIO');
  expect(r.body.error.mensaje).toBe(
    'La refacción no tiene precio de venta registrado: regístralo en el catálogo antes de usarla',
  );
  // El stock no se toca (FR-028).
  const [despues] = await sql('SELECT stock_current FROM parts WHERE id = ?', [partId]);
  expect(despues.stock_current).toBe(antes.stock_current);
});

test('superar_el_tope_del_total_da_409_TOTAL_EXCEDE_LIMITE_FR_008', async () => {
  const ordenId = await ctx.crearOrden();
  // 100 servicios de 999,999.99 = 99,999,999.00; uno más pasa el tope.
  await sql(
    `INSERT INTO order_services (service_order_id, description)
     SELECT ?, CONCAT('Tope ', n) FROM (
       WITH RECURSIVE seq (n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 100)
       SELECT n FROM seq) s`,
    [ordenId],
  );
  await sql(
    `INSERT INTO order_labor (service_order_id, service_id, description, duration_minutes, price)
     SELECT service_order_id, id, description, 10, 999999.99 FROM order_services
     WHERE service_order_id = ?`,
    [ordenId],
  );
  expect((await ctx.total(ordenId)).total).toBe(99999999);

  const partId = await ctx.crearRefaccion({ precioVenta: 1 });
  const r = await ctx.agregarRefaccion(ordenId, partId, 1);
  expect(r.status).toBe(409);
  expect(r.body.error.codigo).toBe('TOTAL_EXCEDE_LIMITE');

  const servicio = await ctx.agregarServicio(ordenId, 1);
  expect(servicio.status).toBe(409);
  expect(servicio.body.error.codigo).toBe('TOTAL_EXCEDE_LIMITE');

  // 0.99 cabe exacto: el total queda en 99,999,999.99.
  const justo = await ctx.agregarServicio(ordenId, 0.99);
  expect(justo.status).toBe(201);
  expect((await ctx.total(ordenId)).total).toBe(99999999.99);
});

test('tres_por_33_33_suma_99_99', async () => {
  const ordenId = await ctx.crearOrden();
  const partId = await ctx.crearRefaccion({ precioVenta: 33.33 });
  expect((await ctx.agregarRefaccion(ordenId, partId, 3)).status).toBe(201);
  const total = await ctx.total(ordenId);
  expect(total.subtotalRefacciones).toBe(99.99);
  expect(total.total).toBe(99.99);
});

test('FR_008_el_importe_en_el_listado_de_pagos_y_en_el_panel_coincide_al_centavo_con_el_total', async () => {
  const partId = await ctx.crearRefaccion({ precioVenta: 33.33 });
  const ordenId = await ctx.ordenTerminada({ precio: 100, refaccion: partId, cantidad: 3 });
  const total = await ctx.total(ordenId);
  expect(total.total).toBe(199.99);

  // Cambia el catálogo antes de cobrar: el cobro usa el precio congelado.
  await ctx.cambiarPrecioVenta(partId, 50);
  const pago = await ctx.pagar(ordenId, total.total);
  expect(pago.status).toBe(201);

  const listado = await api
    .get(`/api/payments/orden/${ordenId}`)
    .set(bearer(ctx.tokens.recepcion));
  expect(listado.body.elementos[0].monto).toBe(total.total);

  // Lo guardado es exactamente el total. El panel (dashboard) solo muestra
  // conteos de órdenes, citas y stock, no importes, así que no hay una cifra
  // del panel que comparar (anotado en reporte-implementacion.md).
  const [fila] = await sql('SELECT amount FROM payments WHERE id = ?', [pago.body.id]);
  expect(fila.amount).toBe('199.99');
});
