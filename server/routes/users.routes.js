// Rutas de usuarios: /api/users — solo rol ADMIN (RN-5, RN-15).
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { userCreateSchema, userUpdateSchema } from '../validators/user.validator.js';
import {
  listUsersHandler,
  createUserHandler,
  updateUserHandler,
} from '../controllers/users.controller.js';

export const usersRoutes = Router();

usersRoutes.use(authenticate, authorize('ADMIN'));

usersRoutes.get('/', asyncHandler(listUsersHandler));
usersRoutes.post('/', validate(userCreateSchema), asyncHandler(createUserHandler));
usersRoutes.patch('/:id', validate(userUpdateSchema), asyncHandler(updateUserHandler));
