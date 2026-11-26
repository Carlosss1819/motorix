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
import { dashboardRoutes } from './dashboard.routes.js';
import { notificationsRoutes } from './notifications.routes.js';
import { clientNoticesRoutes } from './client_notices.routes.js';
// Sprint 7 (Entrega A): configuración, catálogo, términos y bitácora.
import { settingsRoutes } from './settings.routes.js';
import { serviceTypesRoutes } from './service_types.routes.js';
import { termsRoutes } from './terms.routes.js';
import { auditLogRoutes } from './audit_log.routes.js';
// Sprint 7 (Entrega B): reportes.
import { reportsRoutes } from './reports.routes.js';

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
apiRoutes.use('/dashboard', dashboardRoutes);
apiRoutes.use('/notifications', notificationsRoutes);
apiRoutes.use('/client-notices', clientNoticesRoutes);
apiRoutes.use('/settings', settingsRoutes);
apiRoutes.use('/service-types', serviceTypesRoutes);
apiRoutes.use('/terms', termsRoutes);
apiRoutes.use('/audit-log', auditLogRoutes);
apiRoutes.use('/reports', reportsRoutes);
