// Lógica de negocio de los mantenimientos preventivos (US3/US4, Sprint 3):
// unicidad por vehículo y tipo de servicio (clarificación 2), estado calculado
// en cada consulta (R-04) y renovación «servicio realizado» en una sola
// transacción que renueva el MISMO registro (R-05, FR-015).
// Fuente de verdad: specs/003-historial-inventario/contracts/maintenance.md.
import {
  listMaintenance,
  findById,
  findByVehicleAndType,
  createMaintenance,
  updateMaintenance,
  renewMaintenance,
} from '../models/maintenance.js';
import { findById as findVehicleById } from '../models/vehicle.js';
import {
  calcMaintenanceState,
  addDays,
} from '../utils/maintenance-status.js';
import { getConnection } from '../config/db.js';
import { badRequest, conflict, forbidden, notFound } from '../utils/errors.js';

// Fecha local del servidor en `YYYY-MM-DD` (la misma convención que MySQL con
// timezone 'local'; decisión abierta R-11).
function todayIso() {
  const now = new Date();
  const pad = (number) => String(number).padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

// Mapeo al formato del contrato (claves en español) con el estado calculado.
function toApi(row, hoy) {
  const estado = calcMaintenanceState(row, hoy, row.vehicleCurrentMileage);
  return {
    id: row.id,
    vehiculoId: row.vehicleId,
    vehiculo: row.vehicleLabel,
    placas: row.plates,
    cliente: row.clientName ?? null,
    tipoServicio: row.serviceType,
    fechaUltimoServicio: row.lastServiceDate,
    kilometrajeUltimoServicio: row.lastServiceMileage,
    fechaObjetivo: row.targetDate,
    kilometrajeObjetivo: row.targetMileage,
    intervaloDias: row.intervalDays,
    intervaloKm: row.intervalKm,
    antelacionDias: row.advanceDays,
    antelacionKm: row.advanceKm,
    notas: row.notes,
    estado,
  };
}

// Página con el patrón R-10. El filtro por estado se aplica sobre el estado
// CALCULADO, así que la lista se filtra y pagina en memoria: la tabla de
// mantenimientos es pequeña por diseño (un registro por vehículo y tipo).
function paginate(items, page, perPage) {
  const total = items.length;
  const paginas = Math.max(1, Math.ceil(total / perPage));
  const inicio = (page - 1) * perPage;
  return {
    elementos: items.slice(inicio, inicio + perPage),
    pagina: page,
    paginas,
    total,
  };
}

function normalizarPaginacion(filters) {
  const rawPage = Number(filters.pagina);
  const page = Number.isInteger(rawPage) && rawPage > 0 ? rawPage : 1;
  const rawPerPage = Number(filters.porPagina);
  const perPage =
    Number.isInteger(rawPerPage) && rawPerPage > 0 ? Math.min(rawPerPage, 50) : 10;
  return { page, perPage };
}

// Renovación imposible: sin intervalos configurados y sin objetivos en el
// cuerpo no hay hacia dónde mover el objetivo (contrato, sección realizar).
function assertRenovable(maintenance, data) {
  const sinIntervalos = !maintenance.intervalDays && !maintenance.intervalKm;
  const sinObjetivosEnBody = !data.fechaObjetivo && !data.kilometrajeObjetivo;
  if (sinIntervalos && sinObjetivosEnBody) {
    throw badRequest(
      'Este mantenimiento no tiene intervalos configurados: indica los objetivos del próximo servicio o configura un intervalo desde la edición.',
      'MANTENIMIENTO_SIN_INTERVALO',
    );
  }
}

export async function list(filters) {
  const { page, perPage } = normalizarPaginacion(filters);
  const { rows, total } = await listMaintenance({
    vehicleId: filters.vehiculoId,
    search: filters.buscar,
  });
  const hoy = todayIso();
  let elementos = rows.map((row) => toApi(row, hoy));
  if (filters.estado) {
    const deseado = String(filters.estado).toUpperCase();
    elementos = elementos.filter((item) => item.estado === deseado);
  }
  // El total del filtro por estado se calcula antes de paginar.
  const resultado = paginate(elementos, page, perPage);
  return { ...resultado, total: filters.estado ? elementos.length : total };
}

export async function getById(id) {
  const row = await findById(id);
  if (!row) {
    throw notFound('El mantenimiento no existe', 'MANTENIMIENTO_NO_ENCONTRADO');
  }
  return toApi(row, todayIso());
}

export async function create(data, user) {
  const vehicle = await findVehicleById(data.vehiculoId);
  if (!vehicle) {
    throw notFound('El vehículo no existe', 'VEHICULO_NO_ENCONTRADO');
  }
  if (!data.fechaObjetivo && data.kilometrajeObjetivo === undefined) {
    throw badRequest(
      'Indica al menos un objetivo: fecha u kilometraje del próximo servicio',
      'OBJETIVO_REQUERIDO',
    );
  }
  const duplicado = await findByVehicleAndType(data.vehiculoId, data.tipoServicio);
  if (duplicado) {
    throw conflict(
      'Ya existe un mantenimiento de este tipo para el vehículo: edítalo o marca el servicio realizado',
      'MANTENIMIENTO_DUPLICADO',
    );
  }

  const created = await createMaintenance({
    vehicleId: data.vehiculoId,
    serviceType: data.tipoServicio,
    targetDate: data.fechaObjetivo,
    targetMileage: data.kilometrajeObjetivo,
    intervalDays: data.intervaloDias,
    intervalKm: data.intervaloKm,
    advanceDays: data.antelacionDias,
    advanceKm: data.antelacionKm,
    notes: data.notas,
    createdBy: user.id,
  });
  return toApi(created, todayIso());
}

export async function update(id, data) {
  const current = await findById(id);
  if (!current) {
    throw notFound('El mantenimiento no existe', 'MANTENIMIENTO_NO_ENCONTRADO');
  }

  // Objetivo resultante: lo editado o el que ya tenía (no puede quedar sin
  // ninguno de los dos).
  const objetivoFecha = data.fechaObjetivo !== undefined ? data.fechaObjetivo : current.targetDate;
  const objetivoKm =
    data.kilometrajeObjetivo !== undefined ? data.kilometrajeObjetivo : current.targetMileage;
  if (!objetivoFecha && objetivoKm === undefined) {
    throw badRequest(
      'Indica al menos un objetivo: fecha u kilometraje del próximo servicio',
      'OBJETIVO_REQUERIDO',
    );
  }

  const tipoFinal = data.tipoServicio ?? current.serviceType;
  if (tipoFinal !== current.serviceType) {
    const duplicado = await findByVehicleAndType(current.vehicleId, tipoFinal);
    if (duplicado) {
      throw conflict(
        'Ya existe un mantenimiento de este tipo para el vehículo: edítalo o marca el servicio realizado',
        'MANTENIMIENTO_DUPLICADO',
      );
    }
  }

  const updated = await updateMaintenance(id, {
    serviceType: data.tipoServicio,
    targetDate: data.fechaObjetivo,
    targetMileage: data.kilometrajeObjetivo,
    intervalDays: data.intervaloDias,
    intervalKm: data.intervaloKm,
    advanceDays: data.antelacionDias,
    advanceKm: data.antelacionKm,
    notes: data.notas,
  });
  return toApi(updated, todayIso());
}

export async function realizar(id, data, user) {
  const maintenance = await findById(id);
  if (!maintenance) {
    throw notFound('El mantenimiento no existe', 'MANTENIMIENTO_NO_ENCONTRADO');
  }
  const vehicle = await findVehicleById(maintenance.vehicleId);
  if (!vehicle) {
    throw notFound('El vehículo no existe', 'VEHICULO_NO_ENCONTRADO');
  }

  assertRenovable(maintenance, data);

  const fechaServicio = data.fechaServicio ?? todayIso();
  const kilometrajeServicio = data.kilometrajeServicio ?? vehicle.currentMileage;

  // Misma regla de no-regresión del Sprint 2 (FR-006 heredada): la corrección
  // solo la hace ADMIN y su motivo queda guardado.
  if (kilometrajeServicio < vehicle.currentMileage) {
    if (!data.correccionKilometraje) {
      throw badRequest(
        `El kilometraje del servicio no puede ser menor al vigente del vehículo (${vehicle.currentMileage.toLocaleString('es-MX')} km)`,
        'KILOMETRAJE_INVALIDO',
      );
    }
    if (user.role !== 'ADMIN') {
      throw forbidden(
        'Solo un administrador puede corregir el kilometraje del servicio',
        'CORRECCION_NO_AUTORIZADA',
      );
    }
  }

  // Recálculo de objetivos (R-05): desde los intervalos cuando existen; sin
  // intervalos se usan los objetivos del cuerpo o se conservan los actuales
  // (assertRenovable ya garantiza que no falte todo).
  const targetDate = maintenance.intervalDays
    ? addDays(fechaServicio, maintenance.intervalDays)
    : data.fechaObjetivo ?? maintenance.targetDate;
  const targetMileage = maintenance.intervalKm
    ? kilometrajeServicio + maintenance.intervalKm
    : data.kilometrajeObjetivo ?? maintenance.targetMileage;

  const connection = await getConnection();
  try {
    await connection.beginTransaction();
    await renewMaintenance(connection, {
      maintenanceId: maintenance.id,
      vehicleId: maintenance.vehicleId,
      lastServiceDate: fechaServicio,
      lastServiceMileage: kilometrajeServicio,
      targetDate,
      targetMileage,
    });
    await connection.commit();
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }

  // El registro conserva su identidad; el estado se recalcula con los datos
  // renovados (vuelve a NORMAL salvo que el nuevo objetivo ya esté alcanzado).
  const renovado = await findById(id);
  return toApi(renovado, todayIso());
}
