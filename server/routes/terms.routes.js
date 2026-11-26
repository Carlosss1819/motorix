// Rutas de términos y aviso de privacidad: /api/terms (Sprint 7, US9).
// `current` y `accept` están en la lista blanca del middleware de
// autenticación (se pueden usar con la aceptación pendiente, FR-020); la
// lista de aceptaciones es solo de ADMIN (FR-021). No hay edición del texto.
import { Router } from 'express';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { validate } from '../middlewares/validate.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { termsAcceptSchema, termsAcceptancesQuerySchema } from '../validators/terms.validator.js';
import {
  getCurrentTermsHandler,
  acceptTermsHandler,
  listAcceptancesHandler,
} from '../controllers/terms.controller.js';

export const termsRoutes = Router();

termsRoutes.use(authenticate);

termsRoutes.get('/current', asyncHandler(getCurrentTermsHandler));
termsRoutes.post('/accept', validate(termsAcceptSchema), asyncHandler(acceptTermsHandler));
termsRoutes.get(
  '/acceptances',
  authorize('ADMIN'),
  validate(termsAcceptancesQuerySchema, 'query'),
  asyncHandler(listAcceptancesHandler),
);
