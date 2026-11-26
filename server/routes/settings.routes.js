// Rutas de la configuración del taller: /api/settings (Sprint 7, US1/US2).
// Exclusivas de ADMIN, validado en backend (FR-006, RN-15).
import { Router } from 'express';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { settingsUpdateSchema } from '../validators/settings.validator.js';
import { getSettingsHandler, updateSettingsHandler } from '../controllers/settings.controller.js';

export const settingsRoutes = Router();

settingsRoutes.use(authenticate, authorize('ADMIN'));
settingsRoutes.get('/', asyncHandler(getSettingsHandler));
settingsRoutes.put('/', validate(settingsUpdateSchema), asyncHandler(updateSettingsHandler));
