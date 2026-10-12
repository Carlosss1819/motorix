// Variables de entorno para las pruebas: SIEMPRE contra la base motorix_test,
// nunca contra la base principal (Principio VII de la constitucion).
process.env.NODE_ENV = 'test';
process.env.DB_NAME = 'motorix_test';
process.env.JWT_SECRET = process.env.JWT_SECRET ?? 'motorix_test_secret_para_pruebas';
