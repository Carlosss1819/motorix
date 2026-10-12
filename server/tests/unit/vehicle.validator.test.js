// Pruebas unitarias de la validación de vehiculos (RN-1, FR-016, FR-023).
import { vehicleSchema, vehicleUpdateSchema } from '../../validators/vehicle.validator.js';

const validVehicle = {
  clienteId: 1,
  marca: 'Nissan',
  modelo: 'Versa',
  anio: 2020,
  placas: 'ABC1234',
  vin: '3N1AB7AP1KY123456',
  kilometrajeActual: 45000,
};

describe('validación de vehiculos', () => {
  test('acepta un vehiculo completo con propietario', () => {
    const result = vehicleSchema.safeParse(validVehicle);
    expect(result.success).toBe(true);
  });

  test('rechaza el registro sin propietario con el mensaje de RN-1', () => {
    const withoutOwner = { ...validVehicle };
    delete withoutOwner.clienteId;
    const result = vehicleSchema.safeParse(withoutOwner);
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe('Seleccione el propietario');
  });

  test('rechaza un kilometraje negativo', () => {
    const result = vehicleSchema.safeParse({ ...validVehicle, kilometrajeActual: -1 });
    expect(result.success).toBe(false);
    expect(result.error.issues[0].message).toBe('El kilometraje no puede ser negativo');
  });

  test('acepta un vehiculo sin VIN (es opcional)', () => {
    const withoutVin = { ...validVehicle };
    delete withoutVin.vin;
    const result = vehicleSchema.safeParse(withoutVin);
    expect(result.success).toBe(true);
  });

  test('acepta el kilometraje en cero', () => {
    const result = vehicleSchema.safeParse({ ...validVehicle, kilometrajeActual: 0 });
    expect(result.success).toBe(true);
  });

  test('la actualizacion no exige propietario (no se cambia en este sprint)', () => {
    const withoutOwner = { ...validVehicle };
    delete withoutOwner.clienteId;
    const result = vehicleUpdateSchema.safeParse(withoutOwner);
    expect(result.success).toBe(true);
  });
});
