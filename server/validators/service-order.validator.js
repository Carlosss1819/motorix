// Esquemas de validación de órdenes de servicio (US1; la US3 y la US4 añaden
// asignación, diagnóstico, servicios, repuestos y recomendaciones).
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

// Diagnóstico del mecánico (FR-011): `borrador: true` deja el texto sin
// confirmar y el cliente lo descarta si el usuario no guarda (FR-019).
export const diagnosisSchema = z.object({
  texto: z
    .string({ required_error: 'El diagnóstico es obligatorio' })
    .trim()
    .min(1, 'El diagnóstico es obligatorio')
    .max(4000, 'El diagnóstico no puede exceder 4000 caracteres'),
  borrador: z
    .boolean({ invalid_type_error: 'El indicador de borrador debe ser verdadero o falso' })
    .optional()
    .default(false),
});

// Servicio aplicado a la orden (FR-012): se crea junto con su mano de obra.
export const serviceItemSchema = z.object({
  descripcion: z
    .string({ required_error: 'La descripción del servicio es obligatoria' })
    .trim()
    .min(1, 'La descripción del servicio es obligatoria')
    .max(150, 'La descripción del servicio no puede exceder 150 caracteres'),
  duracionMinutos: z
    .number({
      required_error: 'La duración de la mano de obra es obligatoria',
      invalid_type_error: 'La duración de la mano de obra no es un número válido',
    })
    .int('La duración de la mano de obra debe ser un número entero')
    .positive('La duración de la mano de obra debe ser mayor a 0 minutos'),
  precio: z
    .number('El precio de la mano de obra no es un número válido')
    .min(0, 'El precio de la mano de obra no puede ser negativo')
    .optional(),
});

// Repuesto utilizado en la orden (RN-06: solo se registra junto a la orden,
// sin consultar el inventario; eso llega en el Sprint 3).
export const partSchema = z.object({
  descripcion: z
    .string({ required_error: 'La descripción del repuesto es obligatoria' })
    .trim()
    .min(1, 'La descripción del repuesto es obligatoria')
    .max(120, 'La descripción del repuesto no puede exceder 120 caracteres'),
  cantidad: z
    .number({
      required_error: 'La cantidad del repuesto es obligatoria',
      invalid_type_error: 'La cantidad del repuesto no es un número válido',
    })
    .int('La cantidad del repuesto debe ser un número entero')
    .min(1, 'La cantidad del repuesto debe ser al menos 1')
    .optional()
    .default(1),
});

// Recomendaciones para la entrega (FR-013).
export const recommendationSchema = z.object({
  texto: z
    .string({ required_error: 'Las recomendaciones son obligatorias' })
    .trim()
    .min(1, 'Las recomendaciones son obligatorias')
    .max(4000, 'Las recomendaciones no pueden exceder 4000 caracteres'),
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
