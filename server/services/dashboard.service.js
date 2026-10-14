// Lógica del panel de control (Sprint 4, US5 y US6). Reglas aplicadas aquí:
// FR-010 (solo ADMIN lo consume; el servicio solo calcula), FR-011 (indicadores
// con datos reales de los sprints 1 a 3, sin crear copias ni tablas derivadas,
// CA-6) y D4 (un resumen con una sola petición, sin actualización en tiempo
// real). Los bloques operativos reutilizan sus fuentes: citas y refacciones
// con SQL directo; mantenimientos con `calcMaintenanceState` (R-04).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/dashboard.md
import {
  countOrdersByStatus,
  countAppointmentsOn,
  listUpcomingAppointments,
  countLowStockParts,
  listLowStockParts,
} from '../models/dashboard.js';
import { listMaintenance } from '../models/maintenance.js';
import {
  addDays,
  calcMaintenanceState,
  DEFAULT_ADVANCE_DAYS,
  DEFAULT_ADVANCE_KM,
  MAINTENANCE_STATES,
} from '../utils/maintenance-status.js';
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

// Contadores reales de órdenes (FR-010, D4):
//
// - `porEstado` trae siempre los SEIS estados de `ORDER_STATUSES`, con 0 en
//   los que no tengan registros.
// - `abiertas` = todo lo no entregado (`OPEN_ORDER_STATUSES`, es decir,
//   `total - entregadas`) y `entregadas` = `ENTREGADO`.
async function construirOrdenes() {
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
    total,
    abiertas: total - entregadas,
    entregadas,
    porEstado,
  };
}

// `citas`: total del día de referencia (PROGRAMADA o RECIBIDA) y las
// siguientes (máximo 5, orden ascendente). Un bloque sin citas responde `[]`
// y 0 sin errores (HU6-4).
async function construirCitas(referencia) {
  const hoy = await countAppointmentsOn(referencia);
  const proximas = await listUpcomingAppointments(referencia);
  return { hoy, proximas };
}

// La fecha o el kilometraje que disparó la alerta (contrato), con la misma
// prioridad que `calcMaintenanceState`: «vence primero lo que se cumple», es
// decir, se revisa el km y después la fecha.
function objetivoDeAlerta(registro, estado, fecha, kmActual) {
  const vencido = estado === MAINTENANCE_STATES.VENCIDO;
  const advanceDays = registro.advanceDays ?? DEFAULT_ADVANCE_DAYS;
  const advanceKm = registro.advanceKm ?? DEFAULT_ADVANCE_KM;

  if (registro.targetMileage != null && kmActual != null) {
    const umbral = vencido
      ? registro.targetMileage
      : registro.targetMileage - advanceKm;
    if (kmActual >= umbral) return String(registro.targetMileage);
  }
  if (registro.targetDate != null && fecha) {
    const umbral = vencido
      ? registro.targetDate
      : addDays(registro.targetDate, -advanceDays);
    if (fecha >= umbral) return registro.targetDate;
  }
  // Respaldo teórico: una alerta siempre nace de un objetivo configurado.
  if (registro.targetDate != null) return registro.targetDate;
  if (registro.targetMileage != null) return String(registro.targetMileage);
  return '';
}

// `mantenimientos`: reutiliza `calcMaintenanceState` con el día de referencia
// y el kilometraje vigente del vehículo (R-04); `NORMAL` no interesa al
// panel. Los bloques responden siempre como arreglo, aunque estén vacíos
// (HU6-4).
async function construirMantenimientos(referencia) {
  const { rows } = await listMaintenance({});
  const proximos = [];
  const vencidos = [];

  for (const registro of rows) {
    const estado = calcMaintenanceState(
      registro,
      referencia,
      registro.vehicleCurrentMileage,
    );
    if (estado === MAINTENANCE_STATES.NORMAL) continue;

    const linea = {
      id: registro.id,
      vehiculo: [registro.vehicleLabel, registro.plates]
        .filter(Boolean)
        .join(' '),
      tipo: registro.serviceType,
      estado,
      objetivo: objetivoDeAlerta(
        registro,
        estado,
        referencia,
        registro.vehicleCurrentMileage,
      ),
    };

    if (estado === MAINTENANCE_STATES.VENCIDO) vencidos.push(linea);
    else proximos.push(linea);
  }

  return { proximos, vencidos };
}

// `alertasInventario`: total de refacciones en alerta con la regla
// `stockBajo` del inventario (R-10) y máximo 10 filas por faltante
// ascendente (HU6-4: sin datos, contador en 0 y arreglo `[]`).
async function construirAlertas() {
  const stockBajo = await countLowStockParts();
  const refacciones = await listLowStockParts();
  return { stockBajo, refacciones };
}

// Resumen del panel con los contadores reales de los cuatro bloques (FR-010,
// FR-011, D4).
export async function getSummary(fecha = undefined) {
  const referencia = fecha ?? fechaActual();

  const ordenes = await construirOrdenes();
  const citas = await construirCitas(referencia);
  const mantenimientos = await construirMantenimientos(referencia);
  const alertasInventario = await construirAlertas();

  return {
    fecha: referencia,
    ordenes,
    citas,
    mantenimientos,
    alertasInventario,
  };
}
