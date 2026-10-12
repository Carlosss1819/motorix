// Rutas de autenticación: /api/auth
// login es pública; el resto exige sesión válida (JWT + inactividad + cuenta activa).
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { loginSchema, changePasswordSchema } from '../validators/auth.validator.js';
import {
  loginHandler,
  logoutHandler,
  meHandler,
  changePasswordHandler,
} from '../controllers/auth.controller.js';

export const authRoutes = Router();

authRoutes.post('/login', validate(loginSchema), asyncHandler(loginHandler));

authRoutes.use(authenticate);

authRoutes.post('/logout', asyncHandler(logoutHandler));
authRoutes.get('/me', asyncHandler(meHandler));
authRoutes.post(
  '/change-password',
  validate(changePasswordSchema),
  asyncHandler(changePasswordHandler),
);
