// Rutas de los pagos de las órdenes: /api/payments.
// Sprint 4 (US1): registro y consulta para recepción y administración
// (FR-003, RN-15); la anulación se restringe además a ADMIN en el servicio
// (FR-016), con doble validación defensiva aquí.
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import {
  paymentSchema,
  paymentAnnulSchema,
  paymentListQuerySchema,
} from '../validators/payment.validator.js';
import {
  registerPaymentHandler,
  listByOrderHandler,
  annulPaymentHandler,
} from '../controllers/payments.controller.js';

export const paymentsRoutes = Router();

paymentsRoutes.use(authenticate);

// Consulta de los pagos de una orden (incluye anulados, como historial RN-9).
paymentsRoutes.get(
  '/orden/:ordenId',
  authorize('ADMIN', 'RECEPTIONIST'),
  validate(paymentListQuerySchema, 'query'),
  asyncHandler(listByOrderHandler),
);

// Registro del cobro (FR-001, FR-003).
paymentsRoutes.post(
  '/',
  authorize('ADMIN', 'RECEPTIONIST'),
  validate(paymentSchema),
  asyncHandler(registerPaymentHandler),
);

// Anulación de un pago por error de captura (FR-016): solo ADMIN.
paymentsRoutes.post(
  '/:id/anular',
  authorize('ADMIN'),
  validate(paymentAnnulSchema),
  asyncHandler(annulPaymentHandler),
);
