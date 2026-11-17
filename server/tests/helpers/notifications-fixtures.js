// Datos de apoyo para las pruebas del Sprint 6 (avisos internos y clientes
// por avisar). Ajuste M3: el reloj del servidor se fija a una fecha y hora
// conocidas (2035-06-15 12:00) y todas las fechas de prueba se calculan desde
// ese reloj, así que correr la suite cerca de la medianoche (o por la tarde)
// no cambia los resultados. Se usa un día futuro y propio porque la agenda
// real marca como NO_PRESENTADA las citas de HOY cuya hora ya pasó. Ninguna
// otra suite agenda citas cerca de esa fecha: la del panel usa la ventana
// 2040-01-01 a 2100-01-01 y espera cero citas después de 2100-01-05 (HU6-4).
import { api, bearer, loginAs } from './api.js';
import { sql, crearContexto } from './fixtures.js';
import { setNowForTests } from '../../utils/clock.js';
import { toIsoDate, toDbDateTimeLocal } from '../../utils/dates.js';

export const FIXED_NOW = new Date(2035, 5, 15, 12, 0, 0);

export function fijarReloj() {
  setNowForTests(FIXED_NOW);
}

export function liberarReloj() {
  setNowForTests(null);
}

// Fecha `YYYY-MM-DD` a `dias` del reloj fijo.
export function fecha(dias = 0) {
  const d = new Date(FIXED_NOW);
  d.setDate(d.getDate() + dias);
  return toIsoDate(d);
}

// DATETIME local a `horas` del reloj fijo (negativo = en el pasado).
export function fechaHora(horas = 0) {
  return toDbDateTimeLocal(new Date(FIXED_NOW.getTime() + horas * 60 * 60 * 1000));
}

export async function idDeUsuario(username) {
  const [fila] = await sql('SELECT id FROM users WHERE username = ? LIMIT 1', [username]);
  return fila.id;
}

// Contexto del Sprint 5 más funciones para fijar mantenimientos, citas,
// refacciones y órdenes con fechas controladas.
export async function crearContextoAvisos(etiqueta) {
  const ctx = await crearContexto(etiqueta);
  const adminId = await idDeUsuario('admin');
  let n = 0;

  return {
    ...ctx,
    adminId,

    async otroVehiculo(kilometraje = 1000) {
      n += 1;
      const r = await api
        .post('/api/vehicles')
        .set(bearer(ctx.tokens.admin))
        .send({
          clienteId: ctx.clienteId,
          marca: 'Honda',
          modelo: 'Civic',
          anio: 2019,
          placas: `N6${ctx.suffix}${n}`.slice(0, 20),
          kilometrajeActual: kilometraje,
        });
      if (r.status !== 201) throw new Error(`Vehículo: ${JSON.stringify(r.body)}`);
      return r.body.id;
    },

    async mantenimiento({
      vehiculoId = ctx.vehiculoId,
      fechaObjetivo = null,
      kmObjetivo = null,
      antelacionDias = 30,
      antelacionKm = 500,
    } = {}) {
      n += 1;
      const r = await sql(
        `INSERT INTO maintenance (vehicle_id, service_type, target_date, target_mileage,
                                  advance_days, advance_km, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          vehiculoId,
          `Servicio ${etiqueta} ${ctx.suffix} ${n}`.slice(0, 120),
          fechaObjetivo,
          kmObjetivo,
          antelacionDias,
          antelacionKm,
          adminId,
        ],
      );
      return r.insertId;
    },

    async cita({ vehiculoId = ctx.vehiculoId, dia = 0, hora = '18:00:00', estado = 'PROGRAMADA' } = {}) {
      const r = await sql(
        `INSERT INTO appointments (client_id, vehicle_id, appointment_date, appointment_time,
                                   reason, status, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [ctx.clienteId, vehiculoId, fecha(dia), hora, `Cita ${etiqueta} ${ctx.suffix}`, estado, adminId],
      );
      return r.insertId;
    },

    async refaccion({ existencia, minimo, activa = 1 }) {
      n += 1;
      const r = await sql(
        `INSERT INTO parts (code, name, category, brand, stock_current, stock_min,
                            purchase_price, sale_price, is_active)
         VALUES (?, ?, 'Pruebas', 'Motorix', ?, ?, 80.00, 120.00, ?)`,
        [`N6-${ctx.suffix}-${n}`.slice(0, 30), `Refacción ${etiqueta} ${n}`, existencia, minimo, activa],
      );
      return r.insertId;
    },

    // Orden con estado y antigüedad del último cambio controlados.
    async ordenConEstado({ estado = 'DIAGNOSTICO', horasSinCambio = 24 * 5, mecanicoId = null, sinHistorial = false } = {}) {
      const ordenId = await ctx.crearOrden();
      await sql('UPDATE service_orders SET status = ?, mechanic_id = ?, created_at = ? WHERE id = ?', [
        estado,
        mecanicoId,
        fechaHora(-horasSinCambio - 1),
        ordenId,
      ]);
      await sql('DELETE FROM order_status_history WHERE service_order_id = ?', [ordenId]);
      if (!sinHistorial) {
        await sql(
          `INSERT INTO order_status_history (service_order_id, from_status, to_status, changed_by, changed_at)
           VALUES (?, NULL, ?, ?, ?)`,
          [ordenId, estado, adminId, fechaHora(-horasSinCambio)],
        );
      } else {
        await sql('UPDATE service_orders SET created_at = ? WHERE id = ?', [
          fechaHora(-horasSinCambio),
          ordenId,
        ]);
      }
      return ordenId;
    },
  };
}

// Avisos de un token, aplanados, y respuesta completa.
export async function avisosDe(token) {
  const r = await api.get('/api/notifications').set(bearer(token));
  if (r.status !== 200) throw new Error(`Avisos: ${r.status} ${JSON.stringify(r.body)}`);
  return { cuerpo: r.body, avisos: r.body.grupos.flatMap((g) => g.avisos) };
}

export function avisoPorClave(avisos, clave) {
  return avisos.find((a) => a.clave === clave);
}

export async function tokenDe(usuario, contrasena) {
  return loginAs(usuario, contrasena);
}

// Claves de dinero que ningún aviso puede traer (FR-012).
export const CLAVES_DE_DINERO = /"(total|subtotal\w*|precio\w*|importe\w*|monto\w*)"\s*:/i;
