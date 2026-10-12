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

export const vehiclesRoutes = Router();

vehiclesRoutes.use(authenticate, authorize('ADMIN', 'RECEPTIONIST'));

vehiclesRoutes.get(
  '/',
  validate(vehicleListQuerySchema, 'query'),
  asyncHandler(listVehiclesHandler),
);
vehiclesRoutes.post('/', validate(vehicleSchema), asyncHandler(createVehicleHandler));
vehiclesRoutes.get('/:id', asyncHandler(getVehicleHandler));
vehiclesRoutes.put('/:id', validate(vehicleUpdateSchema), asyncHandler(updateVehicleHandler));
