// Aplicacion Express: solo monta rutas, validación y manejo centralizado de errores.
// La logica de negocio vive en services/ (Principio II), nunca aqui.
import express from 'express';
import { apiRoutes } from './routes/index.js';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler.js';

export function createApp() {
  const app = express();

  app.disable('x-powered-by');
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
