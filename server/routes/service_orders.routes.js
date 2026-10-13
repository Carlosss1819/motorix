// Rutas de órdenes de servicio: /api/service-orders.
// US1: lectura y alta para ADMIN y RECEPTIONIST; la US3 habilita la lectura
// del mecánico sobre sus propias órdenes (FR-010, RN-15) y la asignación de
// mecánico desde recepción (FR-009); la US4 registra el contenido de la orden
// (diagnóstico, servicios y recomendaciones) para ADMIN/MECHANIC; la US5
// agrega las transiciones de estado (FR-014, FR-022) y la US7 las refacciones
// del catálogo para los tres roles (FR-023 a FR-027).
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import {
  serviceOrderSchema,
  serviceOrderUpdateSchema,
  serviceOrderAssignSchema,
  serviceOrderStatusSchema,
  serviceOrderListQuerySchema,
  diagnosisSchema,
  serviceItemSchema,
  orderPartSchema,
  recommendationSchema,
} from '../validators/service-order.validator.js';
import {
  listServiceOrdersHandler,
  getServiceOrderHandler,
  createServiceOrderHandler,
  updateServiceOrderHandler,
  assignServiceOrderHandler,
  changeServiceOrderStatusHandler,
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
// obra (FR-012, R-13) y recomendaciones (FR-013). Las registra el mecánico
// sobre sus órdenes o el administrador (FR-022); el servicio además rechaza
// con 409 cualquier cambio en una orden ENTREGADO (FR-016).
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
// Refacciones de la orden (US7, FR-023 a FR-027): salen del catálogo, mueven
// el stock en transacción y las pueden usar los TRES roles sobre una orden
// abierta, con el mecánico limitado a las suyas. `/repuestos` se conserva como
// alias heredado con el mismo handler y la misma respuesta (R-07).
serviceOrdersRoutes.post(
  '/:id/refacciones',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  validate(orderPartSchema),
  asyncHandler(addPartHandler),
);
serviceOrdersRoutes.delete(
  '/:id/refacciones/:refaccionId',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  asyncHandler(removePartHandler),
);
serviceOrdersRoutes.post(
  '/:id/repuestos',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  validate(orderPartSchema),
  asyncHandler(addPartHandler),
);
serviceOrdersRoutes.delete(
  '/:id/repuestos/:repuestoId',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  asyncHandler(removePartHandler),
);
serviceOrdersRoutes.post(
  '/:id/recomendaciones',
  authorize('ADMIN', 'MECHANIC'),
  validate(recommendationSchema),
  asyncHandler(saveRecommendationsHandler),
);

// Transición de estado (US5, FR-014/FR-022): los tres roles participan y el
// servicio aplica el mapa R-02 y la matriz de permisos R-03 (el bloque medio
// es del mecánico asignado o ADMIN; la entrega, de recepción o ADMIN).
serviceOrdersRoutes.post(
  '/:id/estado',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  validate(serviceOrderStatusSchema),
  asyncHandler(changeServiceOrderStatusHandler),
);
