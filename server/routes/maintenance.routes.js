// Rutas de mantenimientos preventivos: /api/maintenance.
// US3/US4 (Sprint 3): lectura para los tres roles (clarificación 4, FR-004);
// escritura y «servicio realizado» solo ADMIN y MECHANIC (FR-008, FR-015).
// El estado no se recibe ni se guarda: lo calcula el backend (R-04).
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import {
  maintenanceSchema,
  maintenanceUpdateSchema,
  realizarSchema,
  maintenanceListQuerySchema,
} from '../validators/maintenance.validator.js';
import {
  listMaintenanceHandler,
  getMaintenanceHandler,
  createMaintenanceHandler,
  updateMaintenanceHandler,
  realizarMaintenanceHandler,
} from '../controllers/maintenance.controller.js';

export const maintenanceRoutes = Router();

maintenanceRoutes.use(authenticate);

maintenanceRoutes.get(
  '/',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  validate(maintenanceListQuerySchema, 'query'),
  asyncHandler(listMaintenanceHandler),
);
maintenanceRoutes.get(
  '/:id',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  asyncHandler(getMaintenanceHandler),
);
maintenanceRoutes.post(
  '/',
  authorize('ADMIN', 'MECHANIC'),
  validate(maintenanceSchema),
  asyncHandler(createMaintenanceHandler),
);
maintenanceRoutes.put(
  '/:id',
  authorize('ADMIN', 'MECHANIC'),
  validate(maintenanceUpdateSchema),
  asyncHandler(updateMaintenanceHandler),
);
maintenanceRoutes.post(
  '/:id/realizar',
  authorize('ADMIN', 'MECHANIC'),
  validate(realizarSchema),
  asyncHandler(realizarMaintenanceHandler),
);
