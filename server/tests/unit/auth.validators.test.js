// Pruebas unitarias de la política de contraseña y la deteccion de usuario/correo.
import {
  isEmail,
  meetsPasswordPolicy,
  loginSchema,
  changePasswordSchema,
} from '../../validators/auth.validator.js';

describe('política mínima de contraseña', () => {
  test('acepta una contraseña que cumple la política', () => {
    expect(meetsPasswordPolicy('Motorix2026')).toBe(true);
  });

  test('rechaza una contraseña corta', () => {
    expect(meetsPasswordPolicy('Ab1')).toBe(false);
  });

  test('rechaza una contraseña sin mayúscula', () => {
    expect(meetsPasswordPolicy('motorix2026')).toBe(false);
  });

  test('rechaza una contraseña sin minúscula', () => {
    expect(meetsPasswordPolicy('MOTORIX2026')).toBe(false);
  });

  test('rechaza una contraseña sin número', () => {
    expect(meetsPasswordPolicy('MotorixSolo')).toBe(false);
  });
});

describe('deteccion de identificador de login (FR-002 / RN-16)', () => {
  test('un valor con "@" se trata como correo electrónico', () => {
    expect(isEmail('admin@motorix.local')).toBe(true);
  });

  test('un valor sin "@" se trata como nombre de usuario', () => {
    expect(isEmail('admin')).toBe(false);
  });
});

describe('esquema de login', () => {
  test('rechaza el identificador vacio con mensaje en espanol', () => {
    const result = loginSchema.safeParse({ identificador: '   ', contrasena: 'x' });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe('Ingrese su usuario o correo electrónico');
  });

  test('acepta un login válido', () => {
    const result = loginSchema.safeParse({ identificador: 'admin', contrasena: 'Admin2026!' });
    expect(result.success).toBe(true);
  });
});

describe('esquema de cambio de contraseña', () => {
  test('rechaza una nueva contrasena que no cumple la política', () => {
    const result = changePasswordSchema.safeParse({ actual: 'x', nueva: 'corta' });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toContain('al menos 8 caracteres');
  });

  test('acepta una contraseña nueva válida', () => {
    const result = changePasswordSchema.safeParse({ actual: 'x', nueva: 'NuevaClave2026' });
    expect(result.success).toBe(true);
  });
});
