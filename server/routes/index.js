// Enrutador principal: agrupa todos los recursos bajo /api.
import { Router } from 'express';
import { authRoutes } from './auth.routes.js';
import { usersRoutes } from './users.routes.js';
import { clientsRoutes } from './clients.routes.js';
import { vehiclesRoutes } from './vehicles.routes.js';
import { serviceOrdersRoutes } from './service_orders.routes.js';
import { appointmentsRoutes } from './appointments.routes.js';
import { maintenanceRoutes } from './maintenance.routes.js';
import { partsRoutes } from './parts.routes.js';
import { paymentsRoutes } from './payments.routes.js';
import { ticketsRoutes } from './tickets.routes.js';

export const apiRoutes = Router();

apiRoutes.use('/auth', authRoutes);
apiRoutes.use('/users', usersRoutes);
apiRoutes.use('/clients', clientsRoutes);
apiRoutes.use('/vehicles', vehiclesRoutes);
apiRoutes.use('/service-orders', serviceOrdersRoutes);
apiRoutes.use('/appointments', appointmentsRoutes);
apiRoutes.use('/maintenance', maintenanceRoutes);
apiRoutes.use('/parts', partsRoutes);
apiRoutes.use('/payments', paymentsRoutes);
apiRoutes.use('/tickets', ticketsRoutes);
