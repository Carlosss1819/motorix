// Rutas de la bitácora: /api/audit-log (Sprint 7, US10, FR-024).
// Solo ADMIN y solo GET: no existen rutas para editar ni borrar entradas.
import { Router } from 'express';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { auditListQuerySchema } from '../validators/audit.validator.js';
import { listAuditLogHandler } from '../controllers/audit_log.controller.js';

export const auditLogRoutes = Router();

auditLogRoutes.use(authenticate, authorize('ADMIN'));
auditLogRoutes.get('/', validate(auditListQuerySchema, 'query'), asyncHandler(listAuditLogHandler));
