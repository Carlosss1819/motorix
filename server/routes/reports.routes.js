// Rutas de los reportes: /api/reports (Sprint 7, Entrega B, FR-038).
// Solo ADMIN y solo GET; `formato=csv` exporta el mismo contenido.
import { Router } from 'express';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { reportQuerySchema } from '../validators/report.validator.js';
import { reportHandler } from '../controllers/reports.controller.js';
import { REPORTS } from '../services/report.service.js';

export const reportsRoutes = Router();

reportsRoutes.use(authenticate, authorize('ADMIN'));
for (const name of Object.keys(REPORTS)) {
  reportsRoutes.get(`/${name}`, validate(reportQuerySchema, 'query'), asyncHandler(reportHandler(name)));
}
