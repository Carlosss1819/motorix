// Rutas de órdenes de servicio: /api/service-orders.
// US1: lectura y alta para ADMIN y RECEPTIONIST; la US3 habilita la lectura
// del mecánico sobre sus propias órdenes (FR-010, RN-15) y la asignación de
// mecánico desde recepción (FR-009); la US4 registra el contenido de la orden
// (diagnóstico, servicios, repuestos y recomendaciones) para ADMIN/MECHANIC.
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
  diagnosisSchema,
  serviceItemSchema,
  partSchema,
  recommendationSchema,
} from '../validators/service-order.validator.js';
import {
  listServiceOrdersHandler,
  getServiceOrderHandler,
  createServiceOrderHandler,
  updateServiceOrderHandler,
  assignServiceOrderHandler,
  saveDiagnosisHandler,
  addServiceHandler,
  removeServiceHandler,
  addPartHandler,
  removePartHandler,
  saveRecommendationsHandler,
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

// Contenido de la orden (US4): diagnóstico (FR-011), servicios con mano de
// obra (FR-012, R-13), repuestos (RN-06) y recomendaciones (FR-013). Las
// registra el mecánico sobre sus órdenes o el administrador (FR-022); el
// servicio además rechaza con 409 cualquier cambio en una orden ENTREGADO
// (FR-016).
serviceOrdersRoutes.post(
  '/:id/diagnostico',
  authorize('ADMIN', 'MECHANIC'),
  validate(diagnosisSchema),
  asyncHandler(saveDiagnosisHandler),
);
serviceOrdersRoutes.post(
  '/:id/servicios',
  authorize('ADMIN', 'MECHANIC'),
  validate(serviceItemSchema),
  asyncHandler(addServiceHandler),
);
serviceOrdersRoutes.delete(
  '/:id/servicios/:servicioId',
  authorize('ADMIN', 'MECHANIC'),
  asyncHandler(removeServiceHandler),
);
serviceOrdersRoutes.post(
  '/:id/repuestos',
  authorize('ADMIN', 'MECHANIC'),
  validate(partSchema),
  asyncHandler(addPartHandler),
);
serviceOrdersRoutes.delete(
  '/:id/repuestos/:repuestoId',
  authorize('ADMIN', 'MECHANIC'),
  asyncHandler(removePartHandler),
);
serviceOrdersRoutes.post(
  '/:id/recomendaciones',
  authorize('ADMIN', 'MECHANIC'),
  validate(recommendationSchema),
  asyncHandler(saveRecommendationsHandler),
);
