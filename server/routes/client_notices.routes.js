// Rutas de «Clientes por avisar»: /api/client-notices (Sprint 6, US7). Solo
// ADMIN y RECEPTIONIST; MECHANIC recibe 403 (FR-022, RN-15).
import { Router } from 'express';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { clientNoticeSchema } from '../validators/notification.validator.js';
import {
  listClientNoticesHandler,
  markNotifiedHandler,
} from '../controllers/client_notices.controller.js';

export const clientNoticesRoutes = Router();

clientNoticesRoutes.use(authenticate, authorize('ADMIN', 'RECEPTIONIST'));

clientNoticesRoutes.get('/', asyncHandler(listClientNoticesHandler));
clientNoticesRoutes.post('/', validate(clientNoticeSchema), asyncHandler(markNotifiedHandler));
