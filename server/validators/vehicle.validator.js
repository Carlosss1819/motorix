// Esquemas de validación de vehiculos.
// RN-1 / FR-017: el propietario es obligatorio. FR-023: placas únicas y VIN único
// cuando se captura. El kilometraje actual no puede ser negativo.
import { z } from 'zod';

export const vehicleSchema = z.object({
  clienteId: z
    .coerce.number({ required_error: 'Seleccione el propietario', invalid_type_error: 'Seleccione el propietario' })
    .int('Seleccione el propietario')
    .positive('Seleccione el propietario'),
  marca: z
    .string({ required_error: 'La marca es obligatoria' })
    .trim()
    .min(1, 'La marca es obligatoria')
    .max(50, 'La marca no puede exceder 50 caracteres'),
  modelo: z
    .string({ required_error: 'El modelo es obligatorio' })
    .trim()
    .min(1, 'El modelo es obligatorio')
    .max(50, 'El modelo no puede exceder 50 caracteres'),
  anio: z
    .coerce.number({ required_error: 'El año es obligatorio', invalid_type_error: 'El año no es válido' })
    .int('El año no es válido')
    .min(1900, 'El año no es válido')
    .max(2100, 'El año no es válido'),
  placas: z
    .string({ required_error: 'Las placas son obligatorias' })
    .trim()
    .min(1, 'Las placas son obligatorias')
    .max(20, 'Las placas no pueden exceder 20 caracteres'),
  vin: z
    .string({ invalid_type_error: 'El VIN no es válido' })
    .trim()
    .nullish()
    .transform((value) => (value ? value : null))
    .refine((value) => !value || value.length <= 20, 'El VIN no puede exceder 20 caracteres'),
  kilometrajeActual: z
    .coerce.number({
      required_error: 'El kilometraje actual es obligatorio',
      invalid_type_error: 'El kilometraje actual no es válido',
    })
    .int('El kilometraje actual no es válido')
    .min(0, 'El kilometraje no puede ser negativo'),
});

export const vehicleListQuerySchema = z.object({
  buscar: z.string().trim().optional(),
  clienteId: z.coerce.number().int().positive().optional(),
});

// Actualización: el propietario no se cambia en este sprint (contracts/vehicles.md).
export const vehicleUpdateSchema = vehicleSchema.omit({ clienteId: true });
