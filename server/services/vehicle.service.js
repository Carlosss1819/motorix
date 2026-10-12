// Logica de negocio de vehiculos: propietario obligatorio (RN-1), placas únicas,
// VIN único cuando existe y kilometraje no negativo (FR-016, FR-023).
import {
  listVehicles,
  findById,
  findByPlates,
  findByVin,
  createVehicle,
  updateVehicle,
} from '../models/vehicle.js';
import { findById as findClientById } from '../models/client.js';
import { badRequest, notFound, conflict } from '../utils/errors.js';

function toApi(vehicle) {
  return {
    id: vehicle.id,
    clienteId: vehicle.clientId,
    dueno: vehicle.ownerName ?? null,
    marca: vehicle.brand,
    modelo: vehicle.model,
    anio: vehicle.year,
    placas: vehicle.plates,
    vin: vehicle.vin ?? '',
    kilometrajeActual: vehicle.currentMileage,
  };
}

export async function list({ search, clientId } = {}) {
  const vehicles = await listVehicles({ search, clientId });
  return vehicles.map(toApi);
}

export async function getById(id) {
  const vehicle = await findById(id);
  if (!vehicle) throw notFound('El vehículo no existe', 'VEHICULO_NO_ENCONTRADO');
  return toApi(vehicle);
}

async function assertOwnerExists(clientId) {
  const owner = await findClientById(clientId);
  if (!owner) {
    throw notFound('El propietario seleccionado no existe', 'PROPIETARIO_INEXISTENTE');
  }
  return owner;
}

async function assertUniquePlates(plates, excludeId = null) {
  const repeated = await findByPlates(plates, excludeId);
  if (repeated) {
    throw conflict('Las placas ya están registradas en otro vehículo', 'PLACAS_EN_USO');
  }
}

async function assertUniqueVin(vin, excludeId = null) {
  const repeated = await findByVin(vin, excludeId);
  if (repeated) {
    throw conflict('El VIN ya está registrado en otro vehículo', 'VIN_EN_USO');
  }
}

export async function create(data) {
  if (!data.clienteId) {
    throw badRequest('Seleccione el propietario', 'PROPIETARIO_REQUERIDO');
  }
  await assertOwnerExists(data.clienteId);
  await assertUniquePlates(data.placas);
  await assertUniqueVin(data.vin);

  const created = await createVehicle({
    clientId: data.clienteId,
    brand: data.marca,
    model: data.modelo,
    year: data.anio,
    plates: data.placas,
    vin: data.vin,
    currentMileage: data.kilometrajeActual,
  });
  return toApi(created);
}

// El propietario no se cambia en este sprint (contracts/vehicles.md).
export async function update(id, data) {
  const existing = await findById(id);
  if (!existing) throw notFound('El vehículo no existe', 'VEHICULO_NO_ENCONTRADO');

  await assertUniquePlates(data.placas, id);
  await assertUniqueVin(data.vin, id);

  const updated = await updateVehicle(id, {
    brand: data.marca,
    model: data.modelo,
    year: data.anio,
    plates: data.placas,
    vin: data.vin,
    currentMileage: data.kilometrajeActual,
  });
  return toApi(updated);
}
