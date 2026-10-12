// Esquemas de validación de clientes.
// Regla de la aclaración Q3: nombre y teléfono obligatorios; correo opcional.
import { z } from 'zod';

const REGEX_CORREO = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const clientSchema = z.object({
  nombre: z
    .string({ required_error: 'El nombre es obligatorio' })
    .trim()
    .min(1, 'El nombre es obligatorio')
    .max(100, 'El nombre no puede exceder 100 caracteres'),
  telefono: z
    .string({ required_error: 'El teléfono es obligatorio' })
    .trim()
    .min(1, 'El teléfono es obligatorio')
    .max(20, 'El teléfono no puede exceder 20 caracteres'),
  email: z
    .string()
    .trim()
    .optional()
    .refine((value) => !value || REGEX_CORREO.test(value), 'El correo electrónico no es válido'),
  confirmar: z.boolean().optional(),
});

export const clientListQuerySchema = z.object({
  buscar: z.string().trim().optional(),
});
