// Rutas de clientes: /api/clients — roles ADMIN y RECEPTIONIST.
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import { clientSchema, clientListQuerySchema } from '../validators/client.validator.js';
import {
  listClientsHandler,
  getClientHandler,
  createClientHandler,
  updateClientHandler,
} from '../controllers/clients.controller.js';

export const clientsRoutes = Router();

clientsRoutes.use(authenticate, authorize('ADMIN', 'RECEPTIONIST'));

clientsRoutes.get('/', validate(clientListQuerySchema, 'query'), asyncHandler(listClientsHandler));
clientsRoutes.post('/', validate(clientSchema), asyncHandler(createClientHandler));
clientsRoutes.get('/:id', asyncHandler(getClientHandler));
clientsRoutes.put('/:id', validate(clientSchema), asyncHandler(updateClientHandler));
