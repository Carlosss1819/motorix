// Controlador del historial del vehículo (US1, Sprint 3).
import { listByVehicle } from '../services/vehicle_history.service.js';
import { sendOk } from '../utils/response.js';

export async function vehicleHistoryHandler(req, res) {
  sendOk(
    res,
    await listByVehicle(Number(req.params.id), req.query),
  );
}
