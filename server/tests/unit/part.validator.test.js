// Pruebas unitarias de la validación de refacciones (US5, Sprint 3):
// código 1-30 caracteres obligatorio, precios y stocks nunca negativos y
// stock mínimo 0 permitido (que nunca genera alerta, FR-021).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
import { partSchema, partUpdateSchema } from '../../validators/part.validator.js';

describe('validación de refacciones (alta)', () => {
  test('acepta un alta completa con stock inicial y precios', () => {
    const result = partSchema.safeParse({
      codigo: 'PAD-001',
      nombre: 'Juego de pastillas delanteras',
      categoria: 'Frenos',
      marca: 'Brembo',
      stockInicial: 10,
      stockMinimo: 5,
      precioCompra: 180,
      precioVenta: 320,
    });
    expect(result.success).toBe(true);
  });

  test('acepta el alta mínima: código, nombre y categoría', () => {
    const result = partSchema.safeParse({
      codigo: 'ACE-5W30',
      nombre: 'Aceite 5W30',
      categoria: 'Lubricantes',
    });
    expect(result.success).toBe(true);
    // Los defaults del contrato: sin stock ni precios.
    expect(result.data.stockInicial).toBe(0);
    expect(result.data.stockMinimo).toBe(0);
  });

  test('acepta stockMinimo 0, que nunca genera alerta de stock bajo', () => {
    const result = partSchema.safeParse({
      codigo: 'FIL-AIR1',
      nombre: 'Filtro de aire',
      categoria: 'Filtros',
      stockInicial: 3,
      stockMinimo: 0,
    });
    expect(result.success).toBe(true);
  });

  test('rechaza el alta sin código', () => {
    const result = partSchema.safeParse({
      nombre: 'Pastillas delanteras',
      categoria: 'Frenos',
    });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe('El código es obligatorio');
  });

  test('rechaza un código vacío', () => {
    const result = partSchema.safeParse({
      codigo: '   ',
      nombre: 'Pastillas delanteras',
      categoria: 'Frenos',
    });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe('El código es obligatorio');
  });

  test('rechaza un código de más de 30 caracteres', () => {
    const result = partSchema.safeParse({
      codigo: 'X'.repeat(31),
      nombre: 'Pastillas delanteras',
      categoria: 'Frenos',
    });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe(
      'El código no puede exceder 30 caracteres',
    );
  });

  test('rechaza un stock inicial negativo', () => {
    const result = partSchema.safeParse({
      codigo: 'PAD-001',
      nombre: 'Pastillas delanteras',
      categoria: 'Frenos',
      stockInicial: -1,
    });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe(
      'El stock inicial no puede ser negativo',
    );
  });

  test('rechaza un stock mínimo negativo', () => {
    const result = partSchema.safeParse({
      codigo: 'PAD-001',
      nombre: 'Pastillas delanteras',
      categoria: 'Frenos',
      stockMinimo: -2,
    });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe(
      'El stock mínimo no puede ser negativo',
    );
  });

  test('rechaza un precio de compra negativo', () => {
    const result = partSchema.safeParse({
      codigo: 'PAD-001',
      nombre: 'Pastillas delanteras',
      categoria: 'Frenos',
      precioCompra: -5,
    });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe(
      'El precio de compra no puede ser negativo',
    );
  });

  test('rechaza un precio de venta negativo', () => {
    const result = partSchema.safeParse({
      codigo: 'PAD-001',
      nombre: 'Pastillas delanteras',
      categoria: 'Frenos',
      precioVenta: -5,
    });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe(
      'El precio de venta no puede ser negativo',
    );
  });
});

describe('validación de refacciones (edición parcial)', () => {
  test('admite cambiar solo el nombre', () => {
    const result = partUpdateSchema.safeParse({ nombre: 'Pastillas Brembo' });
    expect(result.success).toBe(true);
  });

  test('admite el objeto vacío: todo es opcional en el PUT', () => {
    const result = partUpdateSchema.safeParse({});
    expect(result.success).toBe(true);
  });

  test('rechaza un stock mínimo negativo', () => {
    const result = partUpdateSchema.safeParse({ stockMinimo: -1 });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe(
      'El stock mínimo no puede ser negativo',
    );
  });

  test('ignora código y stock actual: no forman parte de la edición', () => {
    const result = partUpdateSchema.safeParse({
      codigo: 'OTRO-CODIGO',
      stockActual: 99,
      nombre: 'Pastillas Brembo',
    });
    expect(result.success).toBe(true);
    expect(result.data).toEqual({ nombre: 'Pastillas Brembo' });
  });
});
