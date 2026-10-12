// Rutas de órdenes de servicio: /api/service-orders.
// US1: lectura y alta para ADMIN y RECEPTIONIST; la US3 habilita la lectura
// del mecánico sobre sus propias órdenes (FR-010, RN-15).
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import {
  serviceOrderSchema,
  serviceOrderUpdateSchema,
  serviceOrderListQuerySchema,
} from '../validators/service-order.validator.js';
import {
  listServiceOrdersHandler,
  getServiceOrderHandler,
  createServiceOrderHandler,
  updateServiceOrderHandler,
} from '../controllers/service_orders.controller.js';

export const serviceOrdersRoutes = Router();

serviceOrdersRoutes.use(authenticate, authorize('ADMIN', 'RECEPTIONIST'));

serviceOrdersRoutes.get(
  '/',
  validate(serviceOrderListQuerySchema, 'query'),
  asyncHandler(listServiceOrdersHandler),
);
serviceOrdersRoutes.post('/', validate(serviceOrderSchema), asyncHandler(createServiceOrderHandler));
serviceOrdersRoutes.get('/:id', asyncHandler(getServiceOrderHandler));
serviceOrdersRoutes.put('/:id', validate(serviceOrderUpdateSchema), asyncHandler(updateServiceOrderHandler));
