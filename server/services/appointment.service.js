// Logica de negocio de las citas de recepcion (US2).
// Reglas aplicadas aqui: RN-01/RN-02 (vehiculo coherente con el cliente),
// FR-005 (datos obligatorios), FR-008/R-05 (conflicto de horario con
// confirmacion explicita), FR-006 (cancelar y recibir solo desde PROGRAMADA,
// motivo de cancelacion opcional y deteccion perezosa a NO_PRESENTADA con
// R-06) y FR-007 (recibir no crea orden: devuelve la precarga).
import {
  listAppointments,
  findAppointmentById,
  createAppointment,
  updateAppointment,
  updateAppointmentStatus,
  findScheduleConflict,
  markExpiredAsNotPresented,
} from '../models/appointment.js';
import { findById as findClientById } from '../models/client.js';
import { findById as findVehicleById } from '../models/vehicle.js';
import { badRequest, conflict, notFound } from '../utils/errors.js';
import { APPOINTMENT_STATUSES } from '../utils/status-constants.js';

// Formatea una fecha como AAAA-MM-DD usando la zona horaria local, para que el
// dia mostrado coincida con el capturado por el usuario.
function formatDate(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  const pad = (number) => String(number).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

// La columna TIME puede llegar como cadena '10:30:00' o como Date; en ambos
// casos se devuelve el horario HH:MM del contrato.
function formatTime(value) {
  if (!value) return null;
  if (value instanceof Date) {
    const pad = (number) => String(number).padStart(2, '0');
    return `${pad(value.getHours())}:${pad(value.getMinutes())}`;
  }
  return String(value).slice(0, 5);
}

function toApiList(appointment) {
  return {
    id: appointment.id,
    clienteId: appointment.clientId,
    cliente: appointment.clientName,
    vehiculoId: appointment.vehicleId,
    vehiculo: appointment.vehicleLabel,
    placas: appointment.plates,
    fecha: formatDate(appointment.appointmentDate),
    hora: formatTime(appointment.appointmentTime),
    motivo: appointment.reason,
    estado: appointment.status,
    motivoCancelacion: appointment.cancelReason ?? '',
    ordenId: appointment.orderId,
  };
}

// RN-01 / RN-02: el cliente y el vehículo deben existir y el vehículo debe
// pertenecer al cliente elegido (FR-002, mismo criterio que las órdenes).
async function assertVehicleOwned(clienteId, vehiculoId) {
  const client = await findClientById(clienteId);
  if (!client) throw notFound('El cliente seleccionado no existe', 'CLIENTE_NO_ENCONTRADO');

  const vehicle = await findVehicleById(vehiculoId);
  if (!vehicle) throw notFound('El vehículo seleccionado no existe', 'VEHICULO_NO_ENCONTRADO');
  if (vehicle.clientId !== clienteId) {
    throw badRequest(
      'El vehículo seleccionado no pertenece al cliente elegido',
      'VEHICULO_NO_PERTENECE',
    );
  }
  return vehicle;
}

// FR-008 / R-05: misma fecha, hora y vehículo en PROGRAMADA o RECIBIDA. El
// alta permite confirmar el reenvio; la edicion no (contrato, seccion PUT),
// por eso `confirmarReenvio` solo se adjunta cuando hay reenvio posible.
async function assertNoScheduleConflict({ vehicleId, fecha, hora, confirmar, excludeId, confirmarReenvio }) {
  if (confirmar) return;
  const clash = await findScheduleConflict({
    vehicleId,
    appointmentDate: fecha,
    appointmentTime: hora,
    excludeId,
  });
  if (!clash) return;
  throw conflict(
    `Ya existe una cita para este vehículo el ${fecha} a las ${hora}`,
    'CITA_CONFLICTO_HORARIO',
    confirmarReenvio ? { pendienteConfirmacion: true, confirmarReenvio: true } : undefined,
  );
}

// Solo las citas PROGRAMADA admiten edicion, cancelacion o recepcion (FR-006).
function assertProgramada(appointment, accion) {
  if (appointment.status !== APPOINTMENT_STATUSES.PROGRAMADA) {
    throw conflict(
      `Solo se pueden ${accion} citas en estado PROGRAMADA`,
      'CITA_NO_PROGRAMADA',
    );
  }
}

export async function list(filters) {
  // FR-006 / R-06: antes de listar se detectan (perezosamente) las citas
  // vencidas que pasan a NO_PRESENTADA.
  await markExpiredAsNotPresented();

  const page = Number(filters.pagina) || 1;
  const perPage = Number(filters.porPagina) || 10;
  const { rows, total } = await listAppointments({
    page,
    perPage,
    search: filters.buscar,
    status: filters.estado,
    date: filters.fecha,
    from: filters.desde,
    to: filters.hasta,
  });
  return {
    elementos: rows.map(toApiList),
    pagina: page,
    paginas: Math.max(1, Math.ceil(total / perPage)),
    total,
  };
}

export async function getById(id) {
  // La deteccion perezosa también aplica al detalle: nunca se muestra una
  // cita vencida como PROGRAMADA (FR-006, R-06).
  await markExpiredAsNotPresented();
  const appointment = await findAppointmentById(id);
  if (!appointment) throw notFound('La cita no existe', 'CITA_NO_ENCONTRADA');
  return {
    ...toApiList(appointment),
    orden: appointment.orderId
      ? {
          id: appointment.orderId,
          estado: appointment.orderStatus,
          fechaIngreso: formatDate(appointment.orderEntryDate),
        }
      : null,
  };
}

export async function create(data, user) {
  const vehicle = await assertVehicleOwned(data.clienteId, data.vehiculoId);

  await assertNoScheduleConflict({
    vehicleId: vehicle.id,
    fecha: data.fecha,
    hora: data.hora,
    confirmar: data.confirmar,
    confirmarReenvio: true,
  });

  const created = await createAppointment({
    clientId: data.clienteId,
    vehicleId: data.vehiculoId,
    appointmentDate: data.fecha,
    appointmentTime: data.hora,
    reason: data.motivo,
    createdBy: user.id,
  });
  return toApiList(created);
}

export async function update(id, data) {
  const appointment = await findAppointmentById(id);
  if (!appointment) throw notFound('La cita no existe', 'CITA_NO_ENCONTRADA');
  assertProgramada(appointment, 'editar');

  await assertNoScheduleConflict({
    vehicleId: appointment.vehicleId,
    fecha: data.fecha,
    hora: data.hora,
    excludeId: id,
    confirmarReenvio: false,
  });

  // Conserva el estado y el motivo de cancelacion: solo cambian fecha, hora y
  // motivo (contrato, seccion PUT).
  const updated = await updateAppointment(id, {
    appointmentDate: data.fecha,
    appointmentTime: data.hora,
    reason: data.motivo,
  });
  return toApiList(updated);
}

export async function cancel(id, data) {
  const appointment = await findAppointmentById(id);
  if (!appointment) throw notFound('La cita no existe', 'CITA_NO_ENCONTRADA');
  assertProgramada(appointment, 'cancelar');

  const updated = await updateAppointmentStatus(id, {
    status: APPOINTMENT_STATUSES.CANCELADA,
    // El motivo es opcional: sin él la columna queda en NULL.
    cancelReason: data.motivo?.trim() || null,
  });
  return toApiList(updated);
}

export async function receive(id) {
  const appointment = await findAppointmentById(id);
  if (!appointment) throw notFound('La cita no existe', 'CITA_NO_ENCONTRADA');
  assertProgramada(appointment, 'recibir');

  const updated = await updateAppointmentStatus(id, {
    status: APPOINTMENT_STATUSES.RECIBIDA,
  });

  // FR-007: recibir NO crea ninguna orden; se devuelve la precarga para que el
  // formulario de orden arranque con los datos de la cita.
  return {
    cita: { id: updated.id, estado: updated.status },
    precargaOrden: {
      clienteId: updated.clientId,
      vehiculoId: updated.vehicleId,
      motivo: updated.reason,
      citaId: updated.id,
    },
  };
}
