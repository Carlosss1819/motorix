// Integración (Sprint 7, US10, FR-022/FR-023, CA-20/CA-21): cada acción
// sensible queda en la bitácora y ninguna entrada guarda contraseñas, hashes
// ni tokens.
import { api, bearer, loginAs } from '../helpers/api.js';
import { prepareTestDatabase } from '../helpers/db.js';
import { crearContexto, sql } from '../helpers/fixtures.js';

let ctx;
let adminId;

async function entradas(accion, entityId) {
  return sql(
    'SELECT user_id, entity_type, entity_id, detail FROM audit_log WHERE action = ? AND entity_id <=> ? ORDER BY id',
    [accion, entityId],
  );
}

beforeAll(async () => {
  await prepareTestDatabase();
  ctx = await crearContexto('Bitácora S7');
  [{ id: adminId }] = await sql("SELECT id FROM users WHERE username = 'admin'");
});

test('test_login_fallido_con_usuario_inexistente_y_existente_y_bloqueo', async () => {
  const fantasma = `fantasma_${ctx.suffix}`;
  await api.post('/api/auth/login').send({ identificador: fantasma, contrasena: 'NoImporta2026!' });
  const sinUsuario = await sql(
    "SELECT user_id, detail FROM audit_log WHERE action = 'LOGIN_FALLIDO' AND detail LIKE ?",
    [`%${fantasma}%`],
  );
  expect(sinUsuario).toEqual([{ user_id: null, detail: `Usuario inexistente: ${fantasma}` }]);

  const username = `bloq_${ctx.suffix}`;
  const creado = await api
    .post('/api/users')
    .set(bearer(ctx.tokens.admin))
    .send({ username, email: `${username}@motorix.local`, rol: 'MECHANIC', contrasena: 'Bloqueo2026!' });
  for (let i = 0; i < 5; i += 1) {
    await api.post('/api/auth/login').send({ identificador: username, contrasena: 'Equivocada2026!' });
  }
  expect(await entradas('LOGIN_FALLIDO', creado.body.id)).toHaveLength(5);
  expect(await entradas('CUENTA_BLOQUEADA', creado.body.id)).toHaveLength(1);
});

test('test_alta_cambio_de_rol_desactivacion_y_activacion_de_usuario', async () => {
  const username = `audit_${ctx.suffix}`;
  const creado = await api
    .post('/api/users')
    .set(bearer(ctx.tokens.admin))
    .send({ username, email: `${username}@motorix.local`, rol: 'MECHANIC', contrasena: 'Auditoria2026!' });
  const id = creado.body.id;
  await api.patch(`/api/users/${id}`).set(bearer(ctx.tokens.admin)).send({ rol: 'RECEPTIONIST' });
  await api.patch(`/api/users/${id}`).set(bearer(ctx.tokens.admin)).send({ estado: 'INACTIVO' });
  await api.patch(`/api/users/${id}`).set(bearer(ctx.tokens.admin)).send({ estado: 'ACTIVO' });

  expect(await entradas('USUARIO_CREADO', id)).toEqual([
    { user_id: adminId, entity_type: 'user', entity_id: id, detail: `${username} (MECHANIC)` },
  ]);
  expect((await entradas('USUARIO_ROL_CAMBIADO', id))[0].detail).toBe(`${username}: MECHANIC → RECEPTIONIST`);
  expect(await entradas('USUARIO_DESACTIVADO', id)).toHaveLength(1);
  expect(await entradas('USUARIO_ACTIVADO', id)).toHaveLength(1);
});

test('test_cambio_de_precio_de_refaccion', async () => {
  const partId = await ctx.crearRefaccion({ precioVenta: 150, precioCompra: 90 });
  await ctx.cambiarPrecioVenta(partId, 180);
  await api.put(`/api/parts/${partId}`).set(bearer(ctx.tokens.admin)).send({ nombre: 'Solo nombre' });
  const filas = await entradas('PRECIO_REFACCION_CAMBIADO', partId);
  expect(filas).toHaveLength(1);
  expect(filas[0].detail).toContain('Precio de venta: 150 → 180');
  expect(filas[0].user_id).toBe(adminId);
});

test('test_pago_anulado_y_pago_cancelado', async () => {
  const ordenA = await ctx.ordenTerminada({ precio: 250 });
  const pagoA = await ctx.pagar(ordenA, 250);
  await ctx.anular(pagoA.body.id);
  expect(await entradas('PAGO_ANULADO', pagoA.body.id)).toHaveLength(1);

  const ordenB = await ctx.ordenTerminada({ precio: 260 });
  const pagoB = await ctx.pagar(ordenB, 260, 'MERCADO_PAGO');
  expect(pagoB.status).toBe(201);
  const cancelado = await ctx.confirmar(pagoB.body.id, 'CANCELADO');
  expect(cancelado.status).toBe(200);
  const filas = await entradas('PAGO_CANCELADO', pagoB.body.id);
  expect(filas).toHaveLength(1);
  expect(filas[0].detail).toContain('MANUAL');
});

test('test_ninguna_entrada_contiene_contrasenas_hashes_ni_tokens', async () => {
  const token = await loginAs('admin', 'Admin2026!');
  const filas = await sql('SELECT detail FROM audit_log WHERE detail IS NOT NULL');
  for (const { detail } of filas) {
    expect(detail).not.toMatch(/\$2[aby]\$/);
    expect(detail).not.toContain(token);
    for (const clave of ['Admin2026!', 'Bloqueo2026!', 'Equivocada2026!', 'Auditoria2026!', 'NoImporta2026!']) {
      expect(detail).not.toContain(clave);
    }
  }
});
