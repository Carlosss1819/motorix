// Rutas del catálogo de tipos de servicio: /api/service-types (Sprint 7, US3).
// Lectura de los activos para los tres roles (registran servicios y
// mantenimientos, FR-009); escritura solo ADMIN. No existe DELETE (FR-008).
import { Router } from 'express';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import {
  serviceTypeCreateSchema,
  serviceTypeUpdateSchema,
  serviceTypeListQuerySchema,
} from '../validators/service-type.validator.js';
import {
  listServiceTypesHandler,
  createServiceTypeHandler,
  updateServiceTypeHandler,
  deactivateServiceTypeHandler,
  activateServiceTypeHandler,
} from '../controllers/service_types.controller.js';

export const serviceTypesRoutes = Router();

serviceTypesRoutes.use(authenticate);

serviceTypesRoutes.get(
  '/',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  validate(serviceTypeListQuerySchema, 'query'),
  asyncHandler(listServiceTypesHandler),
);
serviceTypesRoutes.post('/', authorize('ADMIN'), validate(serviceTypeCreateSchema), asyncHandler(createServiceTypeHandler));
serviceTypesRoutes.put('/:id', authorize('ADMIN'), validate(serviceTypeUpdateSchema), asyncHandler(updateServiceTypeHandler));
serviceTypesRoutes.post('/:id/desactivar', authorize('ADMIN'), asyncHandler(deactivateServiceTypeHandler));
serviceTypesRoutes.post('/:id/activar', authorize('ADMIN'), asyncHandler(activateServiceTypeHandler));
