// Cálculo del total de una orden (Sprint 4, FR-015; reescrito en el Sprint 5,
// FR-008, FR-009, R-06). Módulo puro: recibe los datos armados por el modelo
// y devuelve el total y su desglose, sin tocar la base de datos.
//
// Reglas del Sprint 5:
// - Todo se calcula en centavos enteros (`utils/money.js`), sin flotantes, y
//   se convierte a dos decimales solo para responder.
// - Mano de obra: suma `order_labor.price`, con NULL tratado como 0 y el aviso
//   «sin precio registrado».
// - Refacciones: `cantidad × precioUnitario`, donde `precioUnitario` es el
//   precio CONGELADO de la línea (`order_parts.unit_price`), no el del
//   catálogo. Una línea sin `partId` (heredada) o sin precio vale 0 y lleva el
//   aviso «sin precio registrado».
// - El total es mano de obra + refacciones; no hay un precio de servicio aparte
//   (FR-009).
// - Si algún día la cantidad no es entera, el importe se redondea al centavo
//   hacia arriba desde 0.5.
// La forma de la respuesta es la del Sprint 4.
import { toCents, fromCents } from './money.js';

export const AVISO_SIN_PRECIO = 'sin precio registrado';

// Tope del total de una orden: 99,999,999.99 (FR-008).
export const LIMITE_TOTAL_CENTAVOS = 9999999999;

export function excedeLimite(totalCentavos) {
  return totalCentavos > LIMITE_TOTAL_CENTAVOS;
}

function importeLinea(cantidad, precioCentavos) {
  const importe = cantidad * precioCentavos;
  return Number.isInteger(importe) ? importe : Math.round(importe);
}

// Igual que `calcularTotal`, pero también devuelve los centavos para que los
// servicios comparen y apliquen el tope sin convertir de nuevo.
export function calcularTotalCentavos({ manoDeObra = [], refacciones = [] } = {}) {
  let manoDeObraCentavos = 0;
  const desgloseManoDeObra = [];

  for (const partida of manoDeObra) {
    const precio = toCents(partida.precio) ?? 0;
    manoDeObraCentavos += precio;
    desgloseManoDeObra.push({
      id: partida.id ?? null,
      descripcion: partida.descripcion ?? null,
      precio: fromCents(precio),
      aviso: partida.precio == null ? AVISO_SIN_PRECIO : null,
    });
  }

  let refaccionesCentavos = 0;
  const desgloseRefacciones = [];

  for (const fila of refacciones) {
    const cantidad = fila.cantidad ?? 0;
    const valorada = fila.partId != null && fila.precioUnitario != null;
    const precio = valorada ? toCents(fila.precioUnitario) : 0;
    const importe = importeLinea(cantidad, precio);
    refaccionesCentavos += importe;
    desgloseRefacciones.push({
      id: fila.id ?? null,
      descripcion: fila.descripcion ?? null,
      cantidad,
      precioUnitario: fromCents(precio),
      subtotal: fromCents(importe),
      aviso: valorada ? null : AVISO_SIN_PRECIO,
    });
  }

  const totalCentavos = manoDeObraCentavos + refaccionesCentavos;
  return {
    totalCentavos,
    resultado: {
      subtotalManoDeObra: fromCents(manoDeObraCentavos),
      subtotalRefacciones: fromCents(refaccionesCentavos),
      total: fromCents(totalCentavos),
      desglose: {
        manoDeObra: desgloseManoDeObra,
        refacciones: desgloseRefacciones,
      },
    },
  };
}

// `manoDeObra`: [{ id, descripcion?, precio }] con precio posiblemente null.
// `refacciones`: [{ id?, descripcion, cantidad, partId, precioUnitario }] con
// `precioUnitario` = precio congelado de la línea (null si no tiene).
export function calcularTotal(contenido = {}) {
  return calcularTotalCentavos(contenido).resultado;
}
