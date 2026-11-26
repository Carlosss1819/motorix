// Aplicacion Express: solo monta rutas, validación y manejo centralizado de errores.
// La logica de negocio vive en services/ (Principio II), nunca aqui.
import express from 'express';
import helmet from 'helmet';
import { apiRoutes } from './routes/index.js';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler.js';

export function createApp() {
  const app = express();

  app.disable('x-powered-by');
  // Sprint 7 (US10, FR-030): cabeceras de seguridad estándar. La app web se
  // sirve aparte y llama a /api por proxy (mismo origen), research R-07.
  app.use(helmet());
  app.use(express.json({ limit: '1mb' }));

  // Comprobacion de vida del servicio
  app.get('/api/salud', (req, res) => {
    res.json({ estado: 'ok', servicio: 'motorix-api' });
  });

  app.use('/api', apiRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

export const app = createApp();
