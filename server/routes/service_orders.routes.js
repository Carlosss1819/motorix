// Rutas de órdenes de servicio: /api/service-orders.
// US1: lectura y alta para ADMIN y RECEPTIONIST; la US3 habilita la lectura
// del mecánico sobre sus propias órdenes (FR-010, RN-15) y la asignación de
// mecánico desde recepción (FR-009).
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import {
  serviceOrderSchema,
  serviceOrderUpdateSchema,
  serviceOrderAssignSchema,
  serviceOrderListQuerySchema,
} from '../validators/service-order.validator.js';
import {
  listServiceOrdersHandler,
  getServiceOrderHandler,
  createServiceOrderHandler,
  updateServiceOrderHandler,
  assignServiceOrderHandler,
} from '../controllers/service_orders.controller.js';

export const serviceOrdersRoutes = Router();

serviceOrdersRoutes.use(authenticate);

// Lectura (FR-010): el servicio acota el alcance del mecánico a sus propias
// órdenes; abrir una ajena responde 403.
serviceOrdersRoutes.get(
  '/',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  validate(serviceOrderListQuerySchema, 'query'),
  asyncHandler(listServiceOrdersHandler),
);
serviceOrdersRoutes.get(
  '/:id',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  asyncHandler(getServiceOrderHandler),
);

// Escritura: solo recepción y administración (FR-009, FR-020, FR-022).
serviceOrdersRoutes.post('/', authorize('ADMIN', 'RECEPTIONIST'), validate(serviceOrderSchema), asyncHandler(createServiceOrderHandler));
serviceOrdersRoutes.put('/:id', authorize('ADMIN', 'RECEPTIONIST'), validate(serviceOrderUpdateSchema), asyncHandler(updateServiceOrderHandler));
serviceOrdersRoutes.post(
  '/:id/asignar',
  authorize('ADMIN', 'RECEPTIONIST'),
  validate(serviceOrderAssignSchema),
  asyncHandler(assignServiceOrderHandler),
);
