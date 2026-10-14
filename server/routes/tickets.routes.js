// Rutas de los tickets de servicio: /api/tickets.
// Sprint 4 (US4): generación y consulta para recepción y administración
// (FR-003); el ticket nace de una orden con un pago aprobado (FR-009) y
// nunca se duplica (HU4-2). No hay endpoints de PDF: la impresión es del
// cliente (FR-008, CA-5).
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { ticketGenerateSchema } from '../validators/ticket.validator.js';
import {
  generateTicketHandler,
  getTicketHandler,
  getTicketByOrderHandler,
} from '../controllers/tickets.controller.js';

export const ticketsRoutes = Router();

ticketsRoutes.use(authenticate);

// Generación idempotente del comprobante (FR-009, HU4-2).
ticketsRoutes.post(
  '/',
  authorize('ADMIN', 'RECEPTIONIST'),
  validate(ticketGenerateSchema),
  asyncHandler(generateTicketHandler),
);

// Consulta por orden antes de montar `/orden/:ordenId` (patrón de payments).
ticketsRoutes.get(
  '/orden/:ordenId',
  authorize('ADMIN', 'RECEPTIONIST'),
  asyncHandler(getTicketByOrderHandler),
);

ticketsRoutes.get(
  '/:id',
  authorize('ADMIN', 'RECEPTIONIST'),
  asyncHandler(getTicketHandler),
);
