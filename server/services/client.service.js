// Logica de negocio de clientes: registro, consulta con vehiculos, edicion y aviso de
// teléfono repetido (decisión R-05: avisa y pide confirmación, no bloquea).
import { listClients, findById, findByPhone, createClient, updateClient } from '../models/client.js';
import { listByClient } from '../models/vehicle.js';
import { notFound } from '../utils/errors.js';

function toApi(client) {
  return {
    id: client.id,
    nombre: client.name,
    telefono: client.phone,
    email: client.email ?? '',
    estado: client.status,
    fechaRegistro: client.createdAt ? new Date(client.createdAt).toISOString().slice(0, 10) : null,
  };
}

function vehicleToApi(vehicle) {
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

export async function list(search) {
  const clients = await listClients(search);
  return clients.map(toApi);
}

export async function getById(id) {
  const client = await findById(id);
  if (!client) throw notFound('El cliente no existe', 'CLIENTE_NO_ENCONTRADO');
  const vehicles = await listByClient(client.id);
  return { ...toApi(client), vehiculos: vehicles.map(vehicleToApi) };
}

// Si el teléfono ya existe en otro cliente y no se ha confirmado, devuelve el aviso;
// con confirmar: true procede al registro (contrato contracts/clients.md).
export async function create({ nombre: name, telefono: phone, email, confirmar: confirm }) {
  const existing = await findByPhone(phone);
  if (existing && !confirm) {
    return {
      pendienteConfirmacion: true,
      aviso: 'Ya existe un cliente con este teléfono',
      confirmarReenvio: true,
    };
  }

  const created = await createClient({
    name,
    phone,
    email: email || null,
  });
  return { pendienteConfirmacion: false, cliente: toApi(created) };
}

export async function update(id, { nombre: name, telefono: phone, email }) {
  const existing = await findById(id);
  if (!existing) throw notFound('El cliente no existe', 'CLIENTE_NO_ENCONTRADO');

  const updated = await updateClient(id, {
    name,
    phone,
    email: email || null,
  });
  return toApi(updated);
}
