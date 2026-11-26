// Validación de la configuración del taller (Sprint 7, FR-001 y FR-004).
// Fuente de verdad: specs/007-reportes-configuracion/contracts/settings.md.
import { z } from 'zod';

const texto = (campo, max) =>
  z
    .string({ invalid_type_error: `${campo} debe ser texto` })
    .trim()
    .min(1, `${campo} no puede quedar vacío`)
    .max(max, `${campo} no puede exceder ${max} caracteres`);

const entero = (campo, max) =>
  z
    .number({ invalid_type_error: `${campo} debe ser un número entero` })
    .int(`${campo} debe ser un número entero`)
    .min(1, `${campo} debe ser al menos 1`)
    .max(max, `${campo} no puede ser mayor a ${max}`);

export const settingsUpdateSchema = z
  .object({
    nombreTaller: texto('El nombre del taller', 120).optional(),
    direccionTaller: texto('La dirección del taller', 200).optional(),
    telefonoTaller: texto('El teléfono del taller', 30).optional(),
    antelacionDias: entero('El margen en días', 365).optional(),
    antelacionKm: entero('El margen en kilómetros', 50000).optional(),
  })
  .strict('Hay campos que no se pueden configurar')
  .refine((value) => Object.values(value).some((campo) => campo !== undefined), {
    message: 'Indique al menos un dato de configuración a modificar',
  });
