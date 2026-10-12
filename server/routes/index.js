// Enrutador principal: agrupa todos los recursos bajo /api.
import { Router } from 'express';
import { authRoutes } from './auth.routes.js';
import { usersRoutes } from './users.routes.js';
import { clientsRoutes } from './clients.routes.js';
import { vehiclesRoutes } from './vehicles.routes.js';
import { serviceOrdersRoutes } from './service_orders.routes.js';

export const apiRoutes = Router();

apiRoutes.use('/auth', authRoutes);
apiRoutes.use('/users', usersRoutes);
apiRoutes.use('/clients', clientsRoutes);
apiRoutes.use('/vehicles', vehiclesRoutes);
apiRoutes.use('/service-orders', serviceOrdersRoutes);
