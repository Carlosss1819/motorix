// Variables de entorno para las pruebas: SIEMPRE contra la base de pruebas
// motorix_v2_test, nunca contra la base principal (Principio VII de la
// constitucion). Los nombres motorix_v2 / motorix_v2_test aislan este proyecto
// del prototipo anterior (proyectMototrix), que comparte el equipo local.
process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'motorix_v2_test';
process.env.JWT_SECRET = process.env.JWT_SECRET ?? 'motorix_v2_test_secret_para_pruebas';
