// Punto de entrada del servidor.
import { app } from './app.js';
import { config } from './config/env.js';

const server = app.listen(config.port, () => {
  console.log(`Motorix API escuchando en http://localhost:${config.port}/api`);
  console.log(`Base de datos: ${config.db.host}:${config.db.port}/${config.db.database}`);
});

// Cierre ordenado: cierra el pool de MySQL al detener el proceso.
process.on('SIGINT', () => {
  server.close(() => process.exit(0));
});

process.on('SIGTERM', () => {
  server.close(() => process.exit(0));
});
