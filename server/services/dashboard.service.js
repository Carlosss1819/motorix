// Lógica del panel de control (Sprint 4, US5; US6 agrega los bloques
// operativos). Reglas aplicadas aquí: FR-010 (solo ADMIN lo consume; el
// servicio solo calcula), FR-011 (indicadores con datos reales de los sprints
// 1 a 3, sin crear copias ni tablas derivadas, CA-6) y D4 (un resumen con una
// sola petición, sin actualización en tiempo real).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/dashboard.md
import { countOrdersByStatus } from '../models/dashboard.js';
import {
  ORDER_STATUSES,
  ORDER_STATUS_VALUES,
} from '../utils/status-constants.js';

// Día de referencia por defecto (`AAAA-MM-DD`, fecha local actual).
function fechaActual() {
  const date = new Date();
  const pad = (value) => String(value).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
  );
}

// Resumen del panel con los contadores reales de órdenes (FR-010, D4):
//
// - `porEstado` trae siempre los SEIS estados de `ORDER_STATUSES`, con 0 en
//   los que no tengan registros.
// - `abiertas` = todo lo no entregado (`OPEN_ORDER_STATUSES`, es decir,
//   `total - entregadas`) y `entregadas` = `ENTREGADO`.
export async function getSummary(fecha = undefined) {
  const referencia = fecha ?? fechaActual();
  const conteos = await countOrdersByStatus();

  const porEstado = Object.fromEntries(
    ORDER_STATUS_VALUES.map((estado) => [estado, 0]),
  );
  let total = 0;
  for (const conteo of conteos) {
    if (conteo.status in porEstado) {
      porEstado[conteo.status] = conteo.total;
      total += conteo.total;
    }
  }

  const entregadas = porEstado[ORDER_STATUSES.ENTREGADO];

  return {
    fecha: referencia,
    ordenes: {
      total,
      abiertas: total - entregadas,
      entregadas,
      porEstado,
    },
  };
}
