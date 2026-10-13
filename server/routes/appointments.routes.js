// Rutas de citas de recepción: /api/appointments (US2).
// ADMIN y RECEPTIONIST; MECHANIC recibe 403 (FR-020).
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import {
  appointmentSchema,
  appointmentUpdateSchema,
  appointmentCancelSchema,
  appointmentListQuerySchema,
} from '../validators/appointment.validator.js';
import {
  listAppointmentsHandler,
  getAppointmentHandler,
  createAppointmentHandler,
  updateAppointmentHandler,
  cancelAppointmentHandler,
  receiveAppointmentHandler,
} from '../controllers/appointments.controller.js';

export const appointmentsRoutes = Router();

appointmentsRoutes.use(authenticate, authorize('ADMIN', 'RECEPTIONIST'));

appointmentsRoutes.get(
  '/',
  validate(appointmentListQuerySchema, 'query'),
  asyncHandler(listAppointmentsHandler),
);
appointmentsRoutes.post('/', validate(appointmentSchema), asyncHandler(createAppointmentHandler));
appointmentsRoutes.get('/:id', asyncHandler(getAppointmentHandler));
appointmentsRoutes.put('/:id', validate(appointmentUpdateSchema), asyncHandler(updateAppointmentHandler));
appointmentsRoutes.post('/:id/cancelar', validate(appointmentCancelSchema), asyncHandler(cancelAppointmentHandler));
appointmentsRoutes.post('/:id/recibir', asyncHandler(receiveAppointmentHandler));
