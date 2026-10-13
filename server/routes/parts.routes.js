// Rutas del catalogo de refacciones: /api/parts.
// US5 (Sprint 3): escritura del catalogo, entradas y ajustes solo ADMIN
// (clarificacion 4, FR-022); lectura del inventario los tres roles (FR-022).
// El codigo es identificador unico y el stock_actual solo cambia por
// movimientos, nunca por el cuerpo del alta ni de la edicion (FR-022).
import { Router } from 'express';
import { validate } from '../middlewares/validate.js';
import { authenticate } from '../middlewares/auth.js';
import { authorize } from '../middlewares/authorize.js';
import { asyncHandler } from '../middlewares/asyncHandler.js';
import {
  partSchema,
  partUpdateSchema,
  partsListQuerySchema,
} from '../validators/part.validator.js';
import {
  listPartsHandler,
  getPartHandler,
  createPartHandler,
  updatePartHandler,
  deactivatePartHandler,
} from '../controllers/parts.controller.js';

export const partsRoutes = Router();

partsRoutes.use(authenticate);

// Lectura del inventario: los tres roles (FR-022).
partsRoutes.get(
  '/',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  validate(partsListQuerySchema, 'query'),
  asyncHandler(listPartsHandler),
);
partsRoutes.get(
  '/:id',
  authorize('ADMIN', 'RECEPTIONIST', 'MECHANIC'),
  asyncHandler(getPartHandler),
);

// Escritura del catalogo: solo ADMIN (FR-022).
partsRoutes.post(
  '/',
  authorize('ADMIN'),
  validate(partSchema),
  asyncHandler(createPartHandler),
);
partsRoutes.put(
  '/:id',
  authorize('ADMIN'),
  validate(partUpdateSchema),
  asyncHandler(updatePartHandler),
);
partsRoutes.post(
  '/:id/desactivar',
  authorize('ADMIN'),
  asyncHandler(deactivatePartHandler),
);
