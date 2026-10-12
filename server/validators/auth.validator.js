// Esquemas de validación de autenticación y contraseñas.
import { z } from 'zod';

const POLITICA_CONTRASENA =
  'La contraseña debe tener al menos 8 caracteres y al menos una mayúscula, una minúscula y un número';

// FR-002 / RN-16: el identificador puede ser usuario o correo (se decide por "@").
export function isEmail(valor) {
  return typeof valor === 'string' && valor.includes('@');
}

// RN-17 / FR-008: política mínima del MVP (8 caracteres, mayúscula, minúscula, número).
export function meetsPasswordPolicy(valor) {
  if (typeof valor !== 'string') return false;
  return (
    valor.length >= 8 &&
    /[A-Z]/.test(valor) &&
    /[a-z]/.test(valor) &&
    /[0-9]/.test(valor)
  );
}

const reglaContrasena = z
  .string({ required_error: POLITICA_CONTRASENA })
  .min(8, POLITICA_CONTRASENA)
  .regex(/[A-Z]/, POLITICA_CONTRASENA)
  .regex(/[a-z]/, POLITICA_CONTRASENA)
  .regex(/[0-9]/, POLITICA_CONTRASENA);

export const loginSchema = z.object({
  identificador: z
    .string({ required_error: 'Ingrese su usuario o correo electrónico' })
    .trim()
    .min(1, 'Ingrese su usuario o correo electrónico'),
  contrasena: z.string({ required_error: 'Ingrese su contraseña' }).min(1, 'Ingrese su contraseña'),
});

export const changePasswordSchema = z.object({
  actual: z.string({ required_error: 'Ingrese su contraseña actual' }).min(1, 'Ingrese su contraseña actual'),
  nueva: reglaContrasena,
});
