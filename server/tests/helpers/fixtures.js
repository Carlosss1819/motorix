// Datos de apoyo para las pruebas del Sprint 5: cliente, vehículo, orden,
// servicios, refacciones y pagos creados por la API real, más consultas
// directas a motorix_v2_test cuando la prueba necesita fijar un estado.
import mysql from 'mysql2/promise';
import { api, loginAs, bearer } from './api.js';
import { uniqueSuffix } from './db.js';
import { config } from '../../config/env.js';

export async function sql(query, params = []) {
  const db = await mysql.createConnection(config.db);
  try {
    const [rows] = await db.query(query, params);
    return rows;
  } finally {
    await db.end();
  }
}

export async function fijarEstado(orderId, estado) {
  await sql('UPDATE service_orders SET status = ? WHERE id = ?', [estado, orderId]);
}

// Crea un contexto de prueba: tokens de los tres roles, un cliente y un
// vehículo propios de la suite y funciones para armar órdenes.
export async function crearContexto(etiqueta) {
  const suffix = uniqueSuffix();
  const tokens = {
    admin: await loginAs('admin', 'Admin2026!'),
    recepcion: await loginAs('recepcion', 'Recepcion2026!'),
    mecanico: await loginAs('mecanico', 'Mecanico2026!'),
  };
  const [mecanico] = await sql("SELECT id FROM users WHERE username = 'mecanico' LIMIT 1");
  const mecanicoId = mecanico?.id ?? null;

  const cliente = await api
    .post('/api/clients')
    .set(bearer(tokens.admin))
    .send({ nombre: `${etiqueta} ${suffix}`, telefono: `5${suffix}`.slice(0, 20) });
  if (cliente.status !== 201) throw new Error(`Cliente: ${JSON.stringify(cliente.body)}`);

  const vehiculo = await api
    .post('/api/vehicles')
    .set(bearer(tokens.admin))
    .send({
      clienteId: cliente.body.id,
      marca: 'Nissan',
      modelo: 'Versa',
      anio: 2020,
      placas: `S5${suffix}`.slice(0, 20),
      kilometrajeActual: 1000,
    });
  if (vehiculo.status !== 201) throw new Error(`Vehículo: ${JSON.stringify(vehiculo.body)}`);

  let kilometraje = 1000;
  let contador = 0;

  const ctx = {
    suffix,
    tokens,
    mecanicoId,
    clienteId: cliente.body.id,
    vehiculoId: vehiculo.body.id,

    async crearOrden({ asignarMecanico = false } = {}) {
      kilometraje += 10;
      const body = {
        clienteId: ctx.clienteId,
        vehiculoId: ctx.vehiculoId,
        motivoVisita: `${etiqueta} ${suffix}`,
        fechaIngreso: '2026-11-16',
        kilometraje,
      };
      if (asignarMecanico && mecanicoId) body.mecanicoId = mecanicoId;
      const orden = await api.post('/api/service-orders').set(bearer(tokens.recepcion)).send(body);
      if (orden.status !== 201) throw new Error(`Orden: ${JSON.stringify(orden.body)}`);
      return orden.body.id;
    },

    async agregarServicio(ordenId, precio, token = tokens.admin) {
      contador += 1;
      const body = { descripcion: `Servicio ${suffix} ${contador}`, duracionMinutos: 30 };
      if (precio !== undefined && precio !== null) body.precio = precio;
      return api.post(`/api/service-orders/${ordenId}/servicios`).set(bearer(token)).send(body);
    },

    async crearRefaccion({ precioVenta = 100, precioCompra, stock = 50 } = {}) {
      contador += 1;
      const body = {
        codigo: `S5-${suffix}-${contador}`.slice(0, 30),
        nombre: `Refacción ${etiqueta} ${suffix} ${contador}`,
        categoria: 'Pruebas',
        marca: 'Motorix',
        stockInicial: stock,
        stockMinimo: 1,
      };
      if (precioVenta !== null) body.precioVenta = precioVenta;
      if (precioCompra !== undefined) body.precioCompra = precioCompra;
      const r = await api.post('/api/parts').set(bearer(tokens.admin)).send(body);
      if (r.status !== 201) throw new Error(`Refacción: ${JSON.stringify(r.body)}`);
      return r.body.id;
    },

    async agregarRefaccion(ordenId, partId, cantidad = 1, token = tokens.admin) {
      return api
        .post(`/api/service-orders/${ordenId}/refacciones`)
        .set(bearer(token))
        .send({ partId, cantidad });
    },

    async cambiarPrecioVenta(partId, precioVenta) {
      return api.put(`/api/parts/${partId}`).set(bearer(tokens.admin)).send({ precioVenta });
    },

    async total(ordenId) {
      const r = await api
        .get(`/api/payments/orden/${ordenId}/total`)
        .set(bearer(tokens.recepcion));
      return r.body;
    },

    async pagar(ordenId, monto, metodo = 'EFECTIVO') {
      return api
        .post('/api/payments')
        .set(bearer(tokens.recepcion))
        .send({ ordenId, monto, metodo, fecha: '2026-11-16' });
    },

    async anular(pagoId, motivo = 'Captura con error en la prueba') {
      return api
        .post(`/api/payments/${pagoId}/anular`)
        .set(bearer(tokens.admin))
        .send({ motivo });
    },

    async confirmar(pagoId, estado) {
      return api
        .post(`/api/payments/${pagoId}/confirmar`)
        .set(bearer(tokens.recepcion))
        .send({ estado });
    },

    async generarTicket(ordenId) {
      return api.post('/api/tickets').set(bearer(tokens.recepcion)).send({ ordenId });
    },

    // Orden TERMINADO con mano de obra `precio` y, si se pide, una refacción.
    async ordenTerminada({ precio = 500, refaccion = null, cantidad = 1 } = {}) {
      const ordenId = await ctx.crearOrden();
      if (precio !== null) {
        const s = await ctx.agregarServicio(ordenId, precio);
        if (s.status !== 201) throw new Error(`Servicio: ${JSON.stringify(s.body)}`);
      }
      if (refaccion) {
        const r = await ctx.agregarRefaccion(ordenId, refaccion, cantidad);
        if (r.status !== 201) throw new Error(`Refacción en orden: ${JSON.stringify(r.body)}`);
      }
      await fijarEstado(ordenId, 'TERMINADO');
      return ordenId;
    },
  };
  return ctx;
}
