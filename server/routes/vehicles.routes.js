// Rutas de vehiculos: /api/vehicles — roles ADMIN y RECEPTIONIST.
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import {
  vehicleSchema,
  vehicleUpdateSchema,
  vehicleListQuerySchema,
} from '../validators/vehicle.validator.js';
import {
  listVehiclesHandler,
  getVehicleHandler,
  createVehicleHandler,
  updateVehicleHandler,
} from '../controllers/vehicles.controller.js';
import { vehicleHistoryHandler } from '../controllers/vehicle_history.controller.js';

export const vehiclesRoutes = Router();

// Historial del vehículo (Sprint 3, US1): subrecurso de solo consulta
// disponible para los TRES roles (FR-004, RN-10); se declara antes del
// `use` de escritura porque su matriz de permisos es más amplia.
vehiclesRoutes.get(
  '/:id/history',
  authenticate,
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  asyncHandler(vehicleHistoryHandler),
);

vehiclesRoutes.use(authenticate, authorize('ADMIN', 'RECEPTIONIST'));

vehiclesRoutes.get(
  '/',
  validate(vehicleListQuerySchema, 'query'),
  asyncHandler(listVehiclesHandler),
);
vehiclesRoutes.post('/', validate(vehicleSchema), asyncHandler(createVehicleHandler));
vehiclesRoutes.get('/:id', asyncHandler(getVehicleHandler));
vehiclesRoutes.put('/:id', validate(vehicleUpdateSchema), asyncHandler(updateVehicleHandler));
