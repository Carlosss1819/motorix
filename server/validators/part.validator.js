// Esquemas de validación del catálogo de refacciones (US5, Sprint 3).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
// El código es identificador único (1-30 caracteres); el stock actual no se
// recibe nunca en el alta ni en la edición: solo cambia por movimientos
// (FR-022). `stockMinimo` admite 0, que nunca genera alerta (FR-021).
import { z } from 'zod';

// Entero >= 0 con mensaje propio (los stocks y los precios nunca bajan de 0).
const enteroNoNegativo = (mensaje) =>
  z
    .coerce.number({ invalid_type_error: mensaje })
    .int(mensaje)
    .min(0, mensaje);

const precioNoNegativo = (mensaje) =>
  z
    .coerce.number({ invalid_type_error: mensaje })
    .min(0, mensaje);

export const partSchema = z.object({
  codigo: z
    .string({ required_error: 'El código es obligatorio', invalid_type_error: 'El código es obligatorio' })
    .trim()
    .min(1, 'El código es obligatorio')
    .max(30, 'El código no puede exceder 30 caracteres'),
  nombre: z
    .string({ required_error: 'El nombre es obligatorio', invalid_type_error: 'El nombre es obligatorio' })
    .trim()
    .min(1, 'El nombre es obligatorio')
    .max(120, 'El nombre no puede exceder 120 caracteres'),
  categoria: z
    .string({ required_error: 'La categoría es obligatoria', invalid_type_error: 'La categoría es obligatoria' })
    .trim()
    .min(1, 'La categoría es obligatoria')
    .max(80, 'La categoría no puede exceder 80 caracteres'),
  marca: z
    .string({ invalid_type_error: 'La marca debe ser texto' })
    .trim()
    .max(80, 'La marca no puede exceder 80 caracteres')
    .optional(),
  // Defecto 0 (contrato, seccion POST): si es > 0 se registra ademas la
  // ENTRADA inicial con motivo «Stock inicial» (SC-007).
  stockInicial: enteroNoNegativo('El stock inicial no puede ser negativo').default(0),
  stockMinimo: enteroNoNegativo('El stock mínimo no puede ser negativo').default(0),
  precioCompra: precioNoNegativo('El precio de compra no puede ser negativo').optional(),
  precioVenta: precioNoNegativo('El precio de venta no puede ser negativo').optional(),
});

// Edición parcial (PUT): el código es identificador y el stock actual solo
// cambia por movimientos, así que no forman parte de este esquema (FR-022).
export const partUpdateSchema = z.object({
  nombre: z
    .string({ invalid_type_error: 'El nombre debe ser texto' })
    .trim()
    .min(1, 'El nombre es obligatorio')
    .max(120, 'El nombre no puede exceder 120 caracteres')
    .optional(),
  categoria: z
    .string({ invalid_type_error: 'La categoría debe ser texto' })
    .trim()
    .min(1, 'La categoría es obligatoria')
    .max(80, 'La categoría no puede exceder 80 caracteres')
    .optional(),
  marca: z
    .string({ invalid_type_error: 'La marca debe ser texto' })
    .trim()
    .max(80, 'La marca no puede exceder 80 caracteres')
    .optional(),
  stockMinimo: enteroNoNegativo('El stock mínimo no puede ser negativo').optional(),
  precioCompra: precioNoNegativo('El precio de compra no puede ser negativo').optional(),
  precioVenta: precioNoNegativo('El precio de venta no puede ser negativo').optional(),
});

// Listado con los filtros de FR-018/FR-020 y la paginación estándar R-10.
export const partsListQuerySchema = z.object({
  buscar: z
    .string({ invalid_type_error: 'El texto de búsqueda no es válido' })
    .trim()
    .max(120, 'El texto de búsqueda no puede exceder 120 caracteres')
    .optional(),
  stockBajo: z
    .enum(['true'], {
      errorMap: () => ({ message: 'El filtro de stock bajo no es válido' }),
    })
    .optional(),
  activa: z
    .enum(['true', 'false'], {
      errorMap: () => ({ message: 'El filtro de refacciones activas no es válido' }),
    })
    .optional(),
  pagina: z.coerce.number().int().positive().optional(),
  porPagina: z.coerce.number().int().positive().max(50, 'No se muestran más de 50 registros por página').optional(),
});
