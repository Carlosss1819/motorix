// Variables de entorno para las pruebas: SIEMPRE contra la base de pruebas
// motorix_v2_test, nunca contra la base principal (Principio VII de la
// constitucion). Los nombres motorix_v2 / motorix_v2_test aislan este proyecto
// del prototipo anterior (proyectMototrix), que comparte el equipo local.
process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'motorix_v2_test';
process.env.JWT_SECRET = process.env.JWT_SECRET ?? 'motorix_v2_test_secret_para_pruebas';
// Las pruebas NUNCA llaman a Mercado Pago real (Sprint 6, hallazgo H-S6-01):
// aunque server/.env tenga MP_ACCESS_TOKEN (por ejemplo, tras la prueba manual
// en sandbox), aquí se fuerza la pasarela simulada. Como config/env.js no
// sobrescribe variables ya definidas, la cadena vacía gana sobre el archivo.
process.env.MP_ACCESS_TOKEN = '';
