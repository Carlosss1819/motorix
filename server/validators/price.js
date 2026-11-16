// Esquema Zod reutilizable para precios (Sprint 5, FR-003, FR-032, R-13):
// numérico, ≥ 0, máximo dos decimales y ≤ 999,999.99. Lo usan los precios de
// compra y venta de las refacciones y el precio de la mano de obra.
// Como el valor llega como número de JSON, «máximo dos decimales» se valida
// con una tolerancia para el error de flotante (R-13).
import { z } from 'zod';

export const PRECIO_MAXIMO = 999999.99;

function tieneMaximoDosDecimales(valor) {
  return Math.abs(valor * 100 - Math.round(valor * 100)) < 1e-6;
}

// `campo` nombra el precio en los mensajes («El precio de venta»).
// `coerce` acepta números en texto ('320.50'), como el catálogo desde el
// Sprint 3; la mano de obra solo acepta números (contrato del Sprint 2).
export function priceSchema(campo, { coerce = true } = {}) {
  const mensajeTipo = `${campo} debe ser un número`;
  const base = coerce
    ? z.coerce.number({ invalid_type_error: mensajeTipo, required_error: mensajeTipo })
    : z.number({ invalid_type_error: mensajeTipo, required_error: mensajeTipo });
  return base
    .refine((valor) => Number.isFinite(valor), { message: mensajeTipo })
    .refine((valor) => !Number.isFinite(valor) || valor >= 0, {
      message: `${campo} no puede ser negativo`,
    })
    .refine((valor) => !Number.isFinite(valor) || tieneMaximoDosDecimales(valor), {
      message: `${campo} debe tener máximo 2 decimales`,
    })
    .refine((valor) => !Number.isFinite(valor) || valor <= PRECIO_MAXIMO, {
      message: `${campo} no puede ser mayor a 999,999.99`,
    });
}
