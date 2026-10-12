// Esquemas de validación de usuarios (gestión de cuentas y roles).
import { z } from 'zod';

const REGEX_CORREO = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const POLITICA_CONTRASENA =
  'La contraseña debe tener al menos 8 caracteres y al menos una mayúscula, una minúscula y un número';

export const ROLES_API = ['ADMIN', 'RECEPTIONIST', 'MECHANIC'];
export const ESTADOS_API = ['ACTIVO', 'INACTIVO'];

const reglaContrasena = z
  .string({ required_error: POLITICA_CONTRASENA })
  .min(8, POLITICA_CONTRASENA)
  .regex(/[A-Z]/, POLITICA_CONTRASENA)
  .regex(/[a-z]/, POLITICA_CONTRASENA)
  .regex(/[0-9]/, POLITICA_CONTRASENA);

export const userCreateSchema = z.object({
  username: z
    .string({ required_error: 'El nombre de usuario es obligatorio' })
    .trim()
    .min(3, 'El nombre de usuario debe tener al menos 3 caracteres')
    .max(50, 'El nombre de usuario no puede exceder 50 caracteres'),
  email: z
    .string({ required_error: 'El correo electrónico es obligatorio' })
    .trim()
    .min(1, 'El correo electrónico es obligatorio')
    .refine((value) => REGEX_CORREO.test(value), 'El correo electrónico no es válido'),
  rol: z.enum(ROLES_API, {
    errorMap: (issue) =>
      issue.code === 'invalid_enum_value'
        ? { message: 'Rol no válido: use ADMIN, RECEPTIONIST o MECHANIC' }
        : { message: 'El rol es obligatorio' },
  }),
  contrasena: reglaContrasena,
});

export const userUpdateSchema = z
  .object({
    rol: z
      .enum(ROLES_API, {
        errorMap: () => ({ message: 'Rol no válido: use ADMIN, RECEPTIONIST o MECHANIC' }),
      })
      .optional(),
    estado: z
      .enum(ESTADOS_API, {
        errorMap: () => ({ message: 'Estado no válido: use ACTIVO o INACTIVO' }),
      })
      .optional(),
  })
  .refine((value) => value.rol !== undefined || value.estado !== undefined, {
    message: 'Indique el rol o el estado a modificar',
  });
