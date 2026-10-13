// Esquemas de validacion de citas de recepcion (US2).
// Fuente de verdad: specs/002-citas-ordenes-servicio/contracts/appointments.md
import { z } from 'zod';
import { APPOINTMENT_STATUS_VALUES } from '../utils/status-constants.js';

const REGEX_FECHA = /^\d{4}-\d{2}-\d{2}$/;
const REGEX_HORA = /^([01]\d|2[0-3]):[0-5]\d$/;

export const appointmentSchema = z.object({
  clienteId: z
    .coerce.number({ required_error: 'Seleccione el cliente', invalid_type_error: 'Seleccione el cliente' })
    .int('Seleccione el cliente')
    .positive('Seleccione el cliente'),
  vehiculoId: z
    .coerce.number({ required_error: 'Seleccione el vehículo', invalid_type_error: 'Seleccione el vehículo' })
    .int('Seleccione el vehículo')
    .positive('Seleccione el vehículo'),
  fecha: z
    .string({ required_error: 'La fecha de la cita es obligatoria' })
    .trim()
    .min(1, 'La fecha de la cita es obligatoria')
    .regex(REGEX_FECHA, 'La fecha de la cita debe tener el formato AAAA-MM-DD'),
  hora: z
    .string({ required_error: 'La hora de la cita es obligatoria' })
    .trim()
    .min(1, 'La hora de la cita es obligatoria')
    .regex(REGEX_HORA, 'La hora de la cita debe tener el formato HH:MM'),
  motivo: z
    .string({ required_error: 'El motivo de la cita es obligatorio' })
    .trim()
    .min(1, 'El motivo de la cita es obligatorio')
    .max(255, 'El motivo de la cita no puede exceder 255 caracteres'),
  // Reenvio tras un 409 de conflicto de horario (FR-008): el cliente repite la
  // misma peticion con confirmar: true para guardarla.
  confirmar: z
    .boolean({ invalid_type_error: 'El campo confirmar debe ser verdadero o falso' })
    .optional(),
});

// Edicion (PUT /:id): mismo esquema que el alta pero sin confirmar (contrato).
export const appointmentUpdateSchema = appointmentSchema.omit({ confirmar: true });

// Cancelacion: el motivo es opcional y de hasta 255 caracteres (aclaracion
// del 2026-10-11).
export const appointmentCancelSchema = z.object({
  motivo: z
    .string({ invalid_type_error: 'El motivo de cancelación debe ser texto' })
    .trim()
    .max(255, 'El motivo de cancelación no puede exceder 255 caracteres')
    .optional(),
});

export const appointmentListQuerySchema = z.object({
  fecha: z.string().trim().regex(REGEX_FECHA, 'La fecha debe tener el formato AAAA-MM-DD').optional(),
  desde: z.string().trim().regex(REGEX_FECHA, 'La fecha desde debe tener el formato AAAA-MM-DD').optional(),
  hasta: z.string().trim().regex(REGEX_FECHA, 'La fecha hasta debe tener el formato AAAA-MM-DD').optional(),
  estado: z
    .enum([...APPOINTMENT_STATUS_VALUES], {
      errorMap: () => ({ message: 'El estado indicado no es válido' }),
    })
    .optional(),
  buscar: z.string().trim().optional(),
  pagina: z.coerce
    .number('El número de página no es válido')
    .int('El número de página no es válido')
    .min(1, 'El número de página no puede ser menor a 1')
    .optional(),
  porPagina: z.coerce
    .number('El tamaño de página no es válido')
    .int('El tamaño de página no es válido')
    .min(1, 'El tamaño de página no puede ser menor a 1')
    .max(50, 'El tamaño de página no puede exceder 50')
    .optional(),
});
