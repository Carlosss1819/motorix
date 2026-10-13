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
} from '../models/service_order.js';
import {
  createServiceWithLabor,
  deleteServiceById,
  insertOrderPart,
  findOrderPartRow,
  deleteOrderPart,
  listServicesByOrder,
  listPartsByOrder,
} from '../models/order_items.js';
import {
  findById as findPartById,
  lockStockForUpdate,
  setStock,
} from '../models/parts.js';
import { insertMovement } from '../models/inventory_movement.js';
import { findById as findClientById } from '../models/client.js';
import { findById as findVehicleById, refreshCurrentMileage } from '../models/vehicle.js';
import { findById as findUserById } from '../models/user.js';
import { findAppointmentById } from '../models/appointment.js';
import { getConnection } from '../config/db.js';
import { badRequest, conflict, forbidden, notFound } from '../utils/errors.js';
import { APPOINTMENT_STATUSES, ORDER_STATUSES } from '../utils/status-constants.js';
import { evaluateTransition } from '../utils/order-transitions.js';
import {
  evaluateQuantity,
  evaluateStock,
} from '../utils/order-parts-stock.js';

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

// Asignación o reasignación de mecánico desde recepción (FR-009, FR-022): la
// orden cerrada (TERMINADO/ENTREGADO) no admite cambios y `mecanicoId: null`
// desasigna. El cambio queda en el historial de la orden.
export async function assign(id, data, user) {
  const order = await findServiceOrderById(id);
  if (!order) throw notFound('La orden de servicio no existe', 'ORDEN_NO_ENCONTRADA');

  if (order.status === ORDER_STATUSES.TERMINADO || order.status === ORDER_STATUSES.ENTREGADO) {
    throw conflict(
      'Una orden terminada o entregada no admite reasignación de mecánico',
      'ORDEN_CERRADA',
    );
  }

  let mechanicId = null;
  if (data.mecanicoId !== null) mechanicId = await assertMechanic(data.mecanicoId);

  const updated = await updateServiceOrder(id, { mechanicId });

  await addStatusHistory({
    serviceOrderId: id,
    fromStatus: order.status,
    toStatus: order.status,
    changedBy: user.id,
    note: mechanicId
      ? `Asignación de mecánico: ${updated.mechanicUsername}`
      : 'Desasignación de mecánico',
  });

  return {
    id: updated.id,
    mecanicoId: updated.mechanicId,
    mecanico: updated.mechanicUsername ?? null,
  };
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

// Guard común de la US4: la orden existe, el mecánico solo opera las suyas
// (FR-010, RN-15) y una orden ENTREGADO no admite altas ni bajas de contenido
// (FR-016). Devuelve la orden para reutilizar su estado.
async function assertOrderOpenForContent(id, user) {
  const order = await findServiceOrderById(id);
  if (!order) throw notFound('La orden de servicio no existe', 'ORDEN_NO_ENCONTRADA');
  assertOwnership(order, user);

  if (order.status === ORDER_STATUSES.ENTREGADO) {
    throw conflict(
      'Una orden entregada no admite cambios en su contenido',
      'ORDEN_ENTREGADA',
    );
  }
  return order;
}

// FR-011: el diagnóstico puede quedar en borrador; guardarlo definitivo limpia
// la marca (el texto que no se guarda se descarta en el cliente, FR-019).
export async function saveDiagnosis(id, data, user) {
  const order = await assertOrderOpenForContent(id, user);

  const updated = await updateServiceOrder(order.id, {
    diagnosis: data.texto,
    diagnosisDraft: data.borrador ?? false,
  });

  return {
    diagnostico: updated.diagnosis,
    diagnosticoBorrador: Boolean(updated.diagnosisDraft),
  };
}

// FR-012 / R-13: el servicio y su mano de obra se crean en la misma
// transacción; si falla una, no se guarda ninguna de las dos.
export async function addService(id, data, user) {
  const order = await assertOrderOpenForContent(id, user);

  const created = await createServiceWithLabor({
    serviceOrderId: order.id,
    description: data.descripcion,
    durationMinutes: data.duracionMinutos,
    price: data.precio,
  });

  return {
    servicio: { id: created.id, descripcion: created.description },
    manoDeObra: {
      id: created.labor.id,
      duracionMinutos: created.labor.durationMinutes,
      precio: created.labor.price === null ? null : Number(created.labor.price),
    },
  };
}

// Baja de un servicio; la mano de obra cae en cascada (FK del data-model).
export async function removeService(id, serviceId, user) {
  const order = await assertOrderOpenForContent(id, user);

  const deleted = await deleteServiceById(order.id, serviceId);
  if (!deleted) {
    throw notFound('El servicio no existe en esta orden', 'SERVICIO_NO_ENCONTRADO');
  }

  return { mensaje: 'Servicio eliminado' };
}

// Guard de las refacciones de la orden (US7): además del guard heredado de
// contenido, una orden TERMINADO está cerrada y no admite altas ni bajas
// (FR-026, RN-9 / quickstart V5).
async function assertOrderOpenForParts(id, user) {
  const order = await assertOrderOpenForContent(id, user);
  if (order.status === ORDER_STATUSES.TERMINADO) {
    throw conflict('Una orden cerrada no admite cambios en sus refacciones', 'ORDEN_CERRADA');
  }
  return order;
}

// RN-06 / FR-023: la refacción debe existir en el catálogo y estar activa.
function assertPartUsable(part) {
  if (!part) {
    throw notFound('La refacción no existe', 'REFACCION_NO_ENCONTRADA');
  }
  if (!part.isActive) {
    throw conflict(
      'La refacción está desactivada y no puede agregarse a una orden',
      'REFACCION_INACTIVA',
    );
  }
}

// FR-024 / RN-7 / R-08: la baja de stock, la fila de la orden y el movimiento
// SALIDA ocurren en UNA transacción con la fila de la refacción bloqueada; si
// no alcanza el stock se hace ROLLBACK completo (RN-8: nunca negativo).
export async function addPart(id, data, user) {
  const order = await assertOrderOpenForParts(id, user);
  const refaccion = await findPartById(data.partId);
  assertPartUsable(refaccion);

  const cantidad = evaluateQuantity(data.cantidad);
  if (!cantidad.valida) {
    throw badRequest(cantidad.mensaje, cantidad.codigo);
  }

  const connection = await getConnection();
  try {
    await connection.beginTransaction();

    const stockActual = await lockStockForUpdate(connection, refaccion.id);
    if (stockActual === null) {
      throw notFound('La refacción no existe', 'REFACCION_NO_ENCONTRADA');
    }

    const evaluacion = evaluateStock(stockActual, data.cantidad);
    if (!evaluacion.suficiente) {
      throw conflict(evaluacion.mensaje, evaluacion.codigo);
    }

    await setStock(connection, refaccion.id, evaluacion.stockAfter);
    const fila = await insertOrderPart(connection, {
      serviceOrderId: order.id,
      // Copia histórica del catálogo (R-06): la orden conserva el nombre con
      // el que se usó, aunque la refacción cambie o se desactive después.
      description: refaccion.name,
      quantity: data.cantidad,
      partId: refaccion.id,
    });
    await insertMovement(connection, {
      partId: refaccion.id,
      movementType: 'SALIDA',
      quantity: data.cantidad,
      serviceOrderId: order.id,
      stockAfter: evaluacion.stockAfter,
      createdBy: user.id,
    });

    await connection.commit();
    return {
      id: fila.id,
      partId: refaccion.id,
      codigo: refaccion.code,
      nombre: refaccion.name,
      cantidad: data.cantidad,
      stockActual: evaluacion.stockAfter,
    };
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

// FR-026 / R-09: el retiro repone el stock con una ENTRADA de reposición en
// la misma transacción; una fila heredada sin `part_id` solo se elimina, porque
// nunca descontó inventario.
export async function removePart(id, refaccionId, user) {
  const order = await assertOrderOpenForParts(id, user);

  const connection = await getConnection();
  try {
    await connection.beginTransaction();

    const fila = await findOrderPartRow(connection, order.id, refaccionId);
    if (!fila) {
      throw notFound('La refacción no existe en esta orden', 'REPUESTO_NO_ENCONTRADO');
    }

    let stockRepuesto = null;
    if (fila.part_id) {
      const stockActual = await lockStockForUpdate(connection, fila.part_id);
      if (stockActual === null) {
        throw notFound('La refacción no existe', 'REFACCION_NO_ENCONTRADA');
      }
      stockRepuesto = stockActual + fila.quantity;
      await setStock(connection, fila.part_id, stockRepuesto);
      await insertMovement(connection, {
        partId: fila.part_id,
        movementType: 'ENTRADA',
        quantity: fila.quantity,
        reason: `Reposición por retiro de la orden #${order.id}`,
        serviceOrderId: order.id,
        stockAfter: stockRepuesto,
        createdBy: user.id,
      });
    }

    const borrada = await deleteOrderPart(connection, order.id, fila.id);
    if (!borrada) {
      throw notFound('La refacción no existe en esta orden', 'REPUESTO_NO_ENCONTRADO');
    }

    await connection.commit();
    return {
      mensaje: 'Refacción retirada de la orden.',
      stockActual: stockRepuesto,
    };
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

// FR-013: recomendaciones para la entrega, guardadas en la misma orden.
export async function saveRecommendations(id, data, user) {
  const order = await assertOrderOpenForContent(id, user);

  const updated = await updateServiceOrder(order.id, { recommendations: data.texto });

  return { recomendaciones: updated.recommendations };
}

// Fecha y hora local como 'AAAA-MM-DD HH:MM:SS' para la columna DATETIME de
// la base de datos.
function toDbDateTime(date = new Date()) {
  const pad = (value) => String(value).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

// Transición de estado (US5, FR-014): valida el mapa R-02 y los permisos
// R-03 / FR-022 con la función pura de order-transitions, registra el cambio
// en el historial con usuario y fecha (FR-015) y llena `delivery_date` al
// pasar a ENTREGADO.
export async function changeStatus(id, data, user) {
  const order = await findServiceOrderById(id);
  if (!order) throw notFound('La orden de servicio no existe', 'ORDEN_NO_ENCONTRADA');

  const evaluacion = evaluateTransition({
    fromStatus: order.status,
    toStatus: data.estado,
    role: user.role,
    assignedMechanicId: order.mechanicId,
    userId: user.id,
  });
  if (!evaluacion.permitida) {
    throw evaluacion.httpStatus === 403
      ? forbidden(evaluacion.mensaje, evaluacion.codigo)
      : conflict(evaluacion.mensaje, evaluacion.codigo);
  }

  const entregar = data.estado === ORDER_STATUSES.ENTREGADO;
  const updated = await updateServiceOrder(order.id, {
    status: data.estado,
    // Solo la entrega llena la fecha; el resto de campos no cambian.
    deliveryDate: entregar ? toDbDateTime() : undefined,
  });

  await addStatusHistory({
    serviceOrderId: order.id,
    fromStatus: order.status,
    toStatus: data.estado,
    changedBy: user.id,
    note: data.nota?.trim() || null,
  });

  return toApiDetail(updated);
}
