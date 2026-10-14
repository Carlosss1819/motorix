// Rutas del panel de control: /api/dashboard.
// Sprint 4 (US5): exclusivas de ADMIN (FR-010, RN-15); el contrato usa su
// propio código de error `PANEL_SOLO_ADMIN` (HU5-2, SC-006), así que la
// verificación de rol es un middleware propio en lugar de `authorize`.
import { Router } from 'express';
import { authenticate } from '../middlewares/auth.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { sendError } from '../utils/response.js';
import { dashboardQuerySchema } from '../validators/dashboard.validator.js';
import { getDashboardHandler } from '../controllers/dashboard.controller.js';

export const dashboardRoutes = Router();

// Ocultar el menú no es seguridad: el backend vuelve a filtrar por rol
// (RN-15) con el mensaje del contrato del panel.
function soloPanelAdmin(req, res, next) {
  if (!req.user) {
    return sendError(res, 401, 'Debe iniciar sesión para acceder', 'SESION_REQUERIDA');
  }
  if (req.user.role !== 'ADMIN') {
    return sendError(
      res,
      403,
      'El panel de control es exclusivo del administrador',
      'PANEL_SOLO_ADMIN',
    );
  }
  return next();
}

dashboardRoutes.use(authenticate);

dashboardRoutes.get(
  '/',
  soloPanelAdmin,
  validate(dashboardQuerySchema, 'query'),
  asyncHandler(getDashboardHandler),
);
