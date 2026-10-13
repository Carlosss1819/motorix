// Esquemas de validación de órdenes de servicio (US1).
// Fuente de verdad: specs/002-citas-ordenes-servicio/contracts/service-orders.md
import { z } from 'zod';
import { ORDER_STATUS_VALUES } from '../utils/status-constants.js';

const REGEX_FECHA = /^\d{4}-\d{2}-\d{2}$/;

export const serviceOrderSchema = z.object({
  clienteId: z
    .coerce.number({ required_error: 'Seleccione el cliente', invalid_type_error: 'Seleccione el cliente' })
    .int('Seleccione el cliente')
    .positive('Seleccione el cliente'),
  vehiculoId: z
    .coerce.number({ required_error: 'Seleccione el vehículo', invalid_type_error: 'Seleccione el vehículo' })
    .int('Seleccione el vehículo')
    .positive('Seleccione el vehículo'),
  motivoVisita: z
    .string({ required_error: 'El motivo de visita es obligatorio' })
    .trim()
    .min(1, 'El motivo de visita es obligatorio')
    .max(255, 'El motivo de visita no puede exceder 255 caracteres'),
  fechaIngreso: z
    .string({ required_error: 'La fecha de ingreso es obligatoria' })
    .trim()
    .regex(REGEX_FECHA, 'La fecha de ingreso debe tener el formato AAAA-MM-DD'),
  kilometraje: z
    .coerce.number({
      required_error: 'El kilometraje de entrada es obligatorio',
      invalid_type_error: 'El kilometraje de entrada no es un número válido',
    })
    .int('El kilometraje de entrada debe ser un número entero')
    .min(0, 'El kilometraje de entrada no puede ser negativo'),
  mecanicoId: z.coerce
    .number('El mecánico seleccionado no es válido')
    .int('El mecánico seleccionado no es válido')
    .positive('El mecánico seleccionado no es válido')
    .nullish(),
  citaId: z.coerce
    .number('La cita seleccionada no es válida')
    .int('La cita seleccionada no es válida')
    .positive('La cita seleccionada no es válida')
    .nullish(),
  correccionKilometraje: z
    .string()
    .trim()
    .min(1, 'Indique el motivo de la corrección de kilometraje')
    .max(255, 'El motivo de la corrección no puede exceder 255 caracteres')
    .optional(),
});

// Edición de la orden (PUT /:id): cliente y vehículo no cambian, y la validación
// de kilometraje es la misma que en el alta (contrato, sección PUT).
export const serviceOrderUpdateSchema = z.object({
  motivoVisita: serviceOrderSchema.shape.motivoVisita,
  fechaIngreso: serviceOrderSchema.shape.fechaIngreso,
  kilometraje: serviceOrderSchema.shape.kilometraje,
  correccionKilometraje: serviceOrderSchema.shape.correccionKilometraje,
});

// Asignación de mecánico (FR-009): el campo es obligatorio, pero admite `null`
// explícito para desasignar la orden.
export const serviceOrderAssignSchema = z.object({
  mecanicoId: z
    .number({
      required_error: 'Indique el mecánico que desea asignar',
      invalid_type_error: 'El mecánico seleccionado no es válido',
    })
    .int('El mecánico seleccionado no es válido')
    .positive('El mecánico seleccionado no es válido')
    .nullable(),
});

export const serviceOrderListQuerySchema = z.object({
  estado: z.enum([...ORDER_STATUS_VALUES], { errorMap: () => ({ message: 'El estado indicado no es válido' }) }).optional(),
  estadoAbierta: z.enum(['true', 'false'], { errorMap: () => ({ message: 'El filtro de orden abierta no es válido' }) }).optional(),
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
