// Pruebas unitarias de la validación de clientes (aclaración Q3).
import { clientSchema } from '../../validators/client.validator.js';

describe('validación de clientes', () => {
  test('acepta nombre y telefono sin correo (correo opcional)', () => {
    const result = clientSchema.safeParse({ nombre: 'Maria Lopez', telefono: '5512345678' });
    expect(result.success).toBe(true);
  });

  test('rechaza el registro sin nombre', () => {
    const result = clientSchema.safeParse({ nombre: '', telefono: '5512345678' });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe('El nombre es obligatorio');
  });

  test('rechaza el registro sin telefono', () => {
    const result = clientSchema.safeParse({ nombre: 'Maria Lopez' });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe('El teléfono es obligatorio');
  });

  test('rechaza un correo con formato inválido', () => {
    const result = clientSchema.safeParse({
      nombre: 'Maria Lopez',
      telefono: '5512345678',
      email: 'no-es-correo',
    });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe('El correo electrónico no es válido');
  });

  test('acepta un correo válido', () => {
    const result = clientSchema.safeParse({
      nombre: 'Maria Lopez',
      telefono: '5512345678',
      email: 'maria@correo.com',
    });
    expect(result.success).toBe(true);
  });
});
