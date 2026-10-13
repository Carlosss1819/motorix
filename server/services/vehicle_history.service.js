// Lógica de negocio del historial del vehículo (US1, Sprint 3): vista
// derivada de las órdenes terminadas (RN-10, R-01), paginada con el patrón
// R-10 (defecto 10, máximo 50; la clarificación 5 fija este límite).
// Fuente de verdad: specs/003-historial-inventario/contracts/history.md.
import { listTerminatedByVehicle, vehicleExists } from '../models/vehicle_history.js';
import { notFound } from '../utils/errors.js';

export async function listByVehicle(vehiculoId, filters = {}) {
  const vehicle = await vehicleExists(vehiculoId);
  if (!vehicle) throw notFound('El vehículo no existe', 'VEHICULO_NO_ENCONTRADO');

  // R-10: fuera de rango se corrige al límite sin error (contrato history.md).
  const rawPage = Number(filters.pagina);
  const page = Number.isInteger(rawPage) && rawPage > 0 ? rawPage : 1;
  const rawPerPage = Number(filters.porPagina);
  const perPage =
    Number.isInteger(rawPerPage) && rawPerPage > 0 ? Math.min(rawPerPage, 50) : 10;

  const { rows, total } = await listTerminatedByVehicle(vehiculoId, {
    page,
    perPage,
  });

  return {
    // Claves en español según el contrato history.md (patrón del Sprint 1).
    elementos: rows.map((entry) => ({
      ordenId: entry.orderId,
      fechaServicio: entry.serviceDate,
      kilometraje: entry.mileage,
      estadoOrden: entry.orderStatus,
      observaciones: entry.observations,
      diagnostico: entry.diagnosis,
      recomendaciones: entry.recommendations,
      servicios: entry.services,
      refacciones: entry.parts.map((part) => ({
        partId: part.partId,
        codigo: part.code,
        nombre: part.name,
        cantidad: part.quantity,
      })),
    })),
    pagina: page,
    paginas: Math.max(1, Math.ceil(total / perPage)),
    total,
  };
}
