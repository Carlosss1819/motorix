// Rutas de los avisos internos: /api/notifications (Sprint 6). Los tres roles
// pueden llamarlas; el servicio filtra los avisos por rol y asignación
// (FR-009 a FR-013, RN-15).
import { Router } from 'express';
import { authenticate } from '../middlewares/auth.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { readNoticeSchema } from '../validators/notification.validator.js';
import {
  countNotificationsHandler,
  listNotificationsHandler,
  markReadHandler,
} from '../controllers/notifications.controller.js';

export const notificationsRoutes = Router();

notificationsRoutes.use(authenticate);

notificationsRoutes.get('/', asyncHandler(listNotificationsHandler));
notificationsRoutes.get('/count', asyncHandler(countNotificationsHandler));
notificationsRoutes.post('/read', validate(readNoticeSchema), asyncHandler(markReadHandler));
