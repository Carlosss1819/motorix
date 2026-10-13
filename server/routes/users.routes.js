// Rutas de usuarios: /api/users — gestión de cuentas solo ADMIN (RN-5, RN-15);
// el listado de mecánicos activos también está disponible a recepción para la
// asignación de órdenes (FR-009).
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { userCreateSchema, userUpdateSchema } from '../validators/user.validator.js';
import {
  listUsersHandler,
  listMechanicsHandler,
  createUserHandler,
  updateUserHandler,
} from '../controllers/users.controller.js';

export const usersRoutes = Router();

usersRoutes.use(authenticate);

usersRoutes.get(
  '/mechanics',
  authorize('ADMIN', 'RECEPTIONIST'),
  asyncHandler(listMechanicsHandler),
);

usersRoutes.use(authorize('ADMIN'));

usersRoutes.get('/', asyncHandler(listUsersHandler));
usersRoutes.post('/', validate(userCreateSchema), asyncHandler(createUserHandler));
usersRoutes.patch('/:id', validate(userUpdateSchema), asyncHandler(updateUserHandler));
