// Pruebas de integracion de usuarios (US2): alta de cuentas, cambio de rol con efecto
// inmediato y desactivación que cierra las sesiones abiertas (aclaración Q2).
import { api, loginAs, bearer } from '../helpers/api.js';
import { prepareTestDatabase, uniqueSuffix } from '../helpers/db.js';

let adminToken;
let suffix;

beforeAll(async () => {
  await prepareTestDatabase();
  suffix = uniqueSuffix();
  adminToken = await loginAs('admin', 'Admin2026!');
});

describe('gestion de usuarios (US2)', () => {
  test('un usuario recién creado puede iniciar sesión con su contraseña', async () => {
    const created = await api
      .post('/api/users')
      .set(bearer(adminToken))
      .send({
        username: `nuevo_${suffix}`,
        email: `nuevo_${suffix}@motorix.local`,
        rol: 'MECHANIC',
        contrasena: 'NuevaClave2026',
      });
    expect(created.status).toBe(201);
    expect(created.body.estado).toBe('ACTIVO');

    const login = await api
      .post('/api/auth/login')
      .send({ identificador: `nuevo_${suffix}`, contrasena: 'NuevaClave2026' });
    expect(login.status).toBe(200);
    expect(login.body.usuario.rol).toBe('MECHANIC');
  });

  test('desactivar un usuario cierra su sesión abierta en el mismo momento (Q2)', async () => {
    const created = await api
      .post('/api/users')
      .set(bearer(adminToken))
      .send({
        username: `desact_${suffix}`,
        email: `desact_${suffix}@motorix.local`,
        rol: 'RECEPTIONIST',
        contrasena: 'Desactiva2026!',
      });
    expect(created.status).toBe(201);

    // La víctima inicia sesión y su token funciona.
    const victimToken = await loginAs(`desact_${suffix}`, 'Desactiva2026!');
    const before = await api.get('/api/auth/me').set(bearer(victimToken));
    expect(before.status).toBe(200);

    // El admin la desactiva.
    const patch = await api
      .patch(`/api/users/${created.body.id}`)
      .set(bearer(adminToken))
      .send({ estado: 'INACTIVO' });
    expect(patch.status).toBe(200);
    expect(patch.body.estado).toBe('INACTIVO');

    // El mismo token deja de servir inmediatamente.
    const after = await api.get('/api/auth/me').set(bearer(victimToken));
    expect(after.status).toBe(401);
    expect(after.body.error.codigo).toBe('CUENTA_INACTIVA');

    // Y tampoco puede volver a iniciar sesión.
    const login = await api
      .post('/api/auth/login')
      .send({ identificador: `desact_${suffix}`, contrasena: 'Desactiva2026!' });
    expect(login.status).toBe(403);
    expect(login.body.error.codigo).toBe('CUENTA_INACTIVA');
  });

  test('un cambio de rol surte efecto en la siguiente petición (Q2)', async () => {
    const created = await api
      .post('/api/users')
      .set(bearer(adminToken))
      .send({
        username: `promocion_${suffix}`,
        email: `promocion_${suffix}@motorix.local`,
        rol: 'RECEPTIONIST',
        contrasena: 'Promocion2026!',
      });
    expect(created.status).toBe(201);

    const userToken = await loginAs(`promocion_${suffix}`, 'Promocion2026!');

    // Como RECEPTIONIST no puede gestionar usuarios.
    const denied = await api.get('/api/users').set(bearer(userToken));
    expect(denied.status).toBe(403);

    // El admin lo promueve a ADMIN.
    const patch = await api
      .patch(`/api/users/${created.body.id}`)
      .set(bearer(adminToken))
      .send({ rol: 'ADMIN' });
    expect(patch.status).toBe(200);
    expect(patch.body.rol).toBe('ADMIN');

    // El MISMO token ahora si puede gestionar usuarios: no se renueva la sesión.
    const allowed = await api.get('/api/users').set(bearer(userToken));
    expect(allowed.status).toBe(200);
  });

  test('RECEPTIONIST no puede crear usuarios (403)', async () => {
    const receptionistToken = await loginAs('recepcion', 'Recepcion2026!');
    const response = await api
      .post('/api/users')
      .set(bearer(receptionistToken))
      .send({
        username: `intentorecep_${suffix}`,
        email: `intentorecep_${suffix}@motorix.local`,
        rol: 'MECHANIC',
        contrasena: 'Intento2026!',
      });

    expect(response.status).toBe(403);
    expect(response.body.error.codigo).toBe('ROL_NO_AUTORIZADO');
  });
});
