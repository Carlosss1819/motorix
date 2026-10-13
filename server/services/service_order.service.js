// Logica de negocio de las ordenes de servicio (US1; la US2 a la US5 la amplian).
// Reglas aplicadas aquí: RN-01/RN-02 (cliente y vehículo coherentes), R-08
// (kilometraje no regresivo salvo corrección de ADMIN), FR-014/FR-015 (la orden
// nace en RECIBIDO y se registra en el historial) y RN-15 (alcance por rol).
import {
  listServiceOrders,
  findServiceOrderById,
  findOrderByAppointmentId,
  createServiceOrder,
  updateServiceOrder,
  getLastMileageByVehicle,
  addStatusHistory,
  listStatusHistory,
  listServicesByOrder,
  listPartsByOrder,
} from '../models/service_order.js';
import { findById as findClientById } from '../models/client.js';
import { findById as findVehicleById, refreshCurrentMileage } from '../models/vehicle.js';
import { findById as findUserById } from '../models/user.js';
import { findAppointmentById } from '../models/appointment.js';
import { badRequest, conflict, forbidden, notFound } from '../utils/errors.js';
import { APPOINTMENT_STATUSES, ORDER_STATUSES } from '../utils/status-constants.js';

// Formatea una fecha como AAAA-MM-DD usando la zona horaria local, para que el
// día mostrado coincida con el capturado por el usuario.
function formatDate(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  const pad = (number) => String(number).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function formatDateTime(value) {
  if (!value) return null;
  return new Date(value).toISOString();
}

function toApiList(order) {
  return {
    id: order.id,
    clienteId: order.clientId,
    cliente: order.clientName,
    vehiculoId: order.vehicleId,
    vehiculo: order.vehicleLabel,
    placas: order.plates,
    estado: order.status,
    motivoVisita: order.visitReason,
    fechaIngreso: formatDate(order.entryDate),
    kilometrajeEntrada: order.entryMileage,
    mecanicoId: order.mechanicId,
    mecanico: order.mechanicUsername ?? null,
    citaId: order.appointmentId,
  };
}

async function toApiDetail(order) {
  const [history, services, parts] = await Promise.all([
    listStatusHistory(order.id),
    listServicesByOrder(order.id),
    listPartsByOrder(order.id),
  ]);
  return {
    ...toApiList(order),
    telefono: order.clientPhone,
    notaCorreccionKilometraje: order.mileageCorrectionNote ?? '',
    diagnostico: order.diagnosis,
    diagnosticoBorrador: order.diagnosisDraft,
    recomendaciones: order.recommendations,
    fechaEntrega: formatDateTime(order.deliveryDate),
    servicios: services.map((service) => ({
      id: service.id,
      descripcion: service.description,
      manoDeObra: service.labor
        ? {
            id: service.labor.id,
            duracionMinutos: service.labor.durationMinutes,
            precio: service.labor.price,
          }
        : null,
    })),
    repuestos: parts.map((part) => ({
      id: part.id,
      descripcion: part.description,
      cantidad: part.quantity,
    })),
    historial: history.map((entry) => ({
      de: entry.fromStatus,
      a: entry.toStatus,
      usuario: entry.username,
      fecha: formatDateTime(entry.changedAt),
    })),
  };
}

// Un mecánico solo puede consultar y operar sus propias órdenes (FR-010, RN-15).
function assertOwnership(order, user) {
  if (user.role === 'MECHANIC' && order.mechanicId !== user.id) {
    throw forbidden('No tiene permiso para acceder a esta orden de servicio', 'ORDEN_AJENA');
  }
}

async function assertMechanic(mechanicId) {
  const mechanic = await findUserById(mechanicId);
  if (!mechanic || mechanic.role !== 'MECHANIC' || mechanic.status !== 'ACTIVE') {
    throw notFound('El mecánico seleccionado no existe o no está activo', 'MECANICO_NO_ENCONTRADO');
  }
  return mechanic.id;
}

// R-08 / FR-018: el kilometraje no puede ser menor que el de la última orden del
// vehículo; la corrección es exclusiva de ADMIN y su motivo queda guardado.
// Devuelve la nota de corrección (o null cuando no hace falta corrección).
function validateMileage({ mileage, lastMileage, correction, user }) {
  if (lastMileage === null || mileage >= lastMileage) return null;
  if (!correction) {
    throw badRequest(
      `El kilometraje de entrada no puede ser menor al de la última orden del vehículo (${lastMileage.toLocaleString('es-MX')} km)`,
      'KILOMETRAJE_MENOR',
    );
  }
  if (user.role !== 'ADMIN') {
    throw forbidden(
      'Solo un administrador puede corregir el kilometraje de una orden',
      'CORRECCION_NO_AUTORIZADA',
    );
  }
  return correction;
}

export async function list(filters, user) {
  const page = Number(filters.pagina) || 1;
  const perPage = Number(filters.porPagina) || 10;
  const scope = {
    page,
    perPage,
    search: filters.buscar,
    status: filters.estado,
    openOnly: filters.estadoAbierta === 'true',
  };
  if (user.role === 'MECHANIC') {
    // FR-010 / RN-15: el alcance del mecánico no se puede ampliar con filtros.
    scope.mechanicId = user.id;
  }
  const { rows, total } = await listServiceOrders(scope);
  return {
    elementos: rows.map(toApiList),
    pagina: page,
    paginas: Math.max(1, Math.ceil(total / perPage)),
    total,
  };
}

export async function getById(id, user) {
  const order = await findServiceOrderById(id);
  if (!order) throw notFound('La orden de servicio no existe', 'ORDEN_NO_ENCONTRADA');
  assertOwnership(order, user);
  return toApiDetail(order);
}

export async function create(data, user) {
  const client = await findClientById(data.clienteId);
  if (!client) throw notFound('El cliente seleccionado no existe', 'CLIENTE_NO_ENCONTRADO');

  const vehicle = await findVehicleById(data.vehiculoId);
  if (!vehicle) throw notFound('El vehículo seleccionado no existe', 'VEHICULO_NO_ENCONTRADO');
  if (vehicle.clientId !== data.clienteId) {
    throw badRequest(
      'El vehículo seleccionado no pertenece al cliente elegido',
      'VEHICULO_NO_PERTENECE',
    );
  }

  let mechanicId = null;
  if (data.mecanicoId) mechanicId = await assertMechanic(data.mecanicoId);

  if (data.citaId) {
    // FR-007: la cita debe existir, estar RECIBIDA y no estar usada ya en otra
    // orden (el enlace es UNIQUE en service_orders.appointment_id).
    const appointment = await findAppointmentById(data.citaId);
    if (!appointment) throw notFound('La cita seleccionada no existe', 'CITA_NO_ENCONTRADA');
    if (appointment.status !== APPOINTMENT_STATUSES.RECIBIDA) {
      throw conflict(
        'La cita debe estar en estado RECIBIDA para derivar en una orden de servicio',
        'CITA_NO_RECIBIDA',
      );
    }
    const linkedOrder = await findOrderByAppointmentId(appointment.id);
    if (linkedOrder) {
      throw conflict('La cita ya derivó en otra orden de servicio', 'CITA_YA_UTILIZADA');
    }
  }

  // R-08 / FR-018: el kilometraje de entrada no puede ser menor que el de la
  // última orden del vehículo; la corrección es exclusiva del administrador.
  const lastMileage = await getLastMileageByVehicle(vehicle.id);
  const mileageCorrectionNote = validateMileage({
    mileage: data.kilometraje,
    lastMileage,
    correction: data.correccionKilometraje,
    user,
  });

  const created = await createServiceOrder({
    clientId: client.id,
    vehicleId: vehicle.id,
    appointmentId: data.citaId ?? null,
    visitReason: data.motivoVisita,
    entryDate: data.fechaIngreso,
    entryMileage: data.kilometraje,
    mechanicId,
    mileageCorrectionNote,
    createdBy: user.id,
  });

  // FR-014 / FR-015: toda orden nace en RECIBIDO y deja rastro en el historial.
  await addStatusHistory({
    serviceOrderId: created.id,
    fromStatus: null,
    toStatus: ORDER_STATUSES.RECIBIDO,
    changedBy: user.id,
    note: 'Alta de la orden',
  });

  await refreshCurrentMileage(vehicle.id, data.kilometraje);

  return toApiDetail(await findServiceOrderById(created.id));
}

// Edición de la orden (PUT /:id): cliente y vehículo no cambian, y no aplica a
// órdenes terminadas ni entregadas (contrato; R-08 / FR-018 en el kilometraje).
export async function update(id, data, user) {
  const order = await findServiceOrderById(id);
  if (!order) throw notFound('La orden de servicio no existe', 'ORDEN_NO_ENCONTRADA');
  assertOwnership(order, user);

  if (order.status === ORDER_STATUSES.TERMINADO || order.status === ORDER_STATUSES.ENTREGADO) {
    throw conflict('Una orden terminada o entregada no puede modificarse', 'ORDEN_CERRADA');
  }

  const lastMileage = await getLastMileageByVehicle(order.vehicleId, order.id);
  const mileageCorrectionNote = validateMileage({
    mileage: data.kilometraje,
    lastMileage,
    correction: data.correccionKilometraje,
    user,
  });

  const updated = await updateServiceOrder(id, {
    visitReason: data.motivoVisita,
    entryDate: data.fechaIngreso,
    entryMileage: data.kilometraje,
    // Sin corrección explícita se conserva la nota ya registrada.
    mileageCorrectionNote: mileageCorrectionNote ?? undefined,
  });

  await refreshCurrentMileage(order.vehicleId, data.kilometraje);

  return toApiDetail(updated);
}
