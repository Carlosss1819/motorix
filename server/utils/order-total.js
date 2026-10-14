// Cálculo del total de una orden al momento de cobrar (Sprint 4, FR-015).
// Módulo puro al estilo de maintenance-status.js y order-transitions.js:
// recibe los datos armados por el modelo y devuelve el total y su desglose,
// sin tocar la base de datos, para probarlo en unidad.
// Fuente de verdad: specs/004-pagos-tickets-dashboard/research.md (D2, D2.1).
//
// Reglas (aclaración 2 del 2026-10-13):
// - Mano de obra: suma `order_labor.price`, con NULL tratado como 0 (el precio
//   es opcional desde el Sprint 2).
// - Refacciones: suma `parts.sale_price × order_parts.quantity` de las filas
//   con `part_id` (precio vigente del catálogo al cobrar).
// - Filas heredadas sin `part_id` (Sprint 2) se valoran en 0 y llevan el aviso
//   «sin precio registrado» en el desglose (D2.1); su cantidad sí se lista.

const AVISO_SIN_PRECIO = 'sin precio registrado';

// Redondea a dos decimales para que la suma no acumre error de flotantes
// (los montos se guardan como DECIMAL(10,2)).
function redondear(valor) {
  return Math.round((valor + Number.EPSILON) * 100) / 100;
}

// `manoDeObra`: [{ id, descripcion?, precio }] con precio posiblemente null.
// `refacciones`: [{ id?, descripcion, cantidad, partId, precioUnitario }] con
// `precioUnitario` = `sale_price` vigente del catálogo (null si no existe).
export function calcularTotal({ manoDeObra = [], refacciones = [] } = {}) {
  let subtotalManoDeObra = 0;
  const desgloseManoDeObra = [];

  for (const partida of manoDeObra) {
    const precio = partida.precio ?? 0;
    subtotalManoDeObra += precio;
    desgloseManoDeObra.push({
      id: partida.id ?? null,
      descripcion: partida.descripcion ?? null,
      precio: redondear(precio),
      aviso: partida.precio == null ? AVISO_SIN_PRECIO : null,
    });
  }

  let subtotalRefacciones = 0;
  const desgloseRefacciones = [];

  for (const fila of refacciones) {
    const cantidad = fila.cantidad ?? 0;
    // Fila heredada sin catálogo: valor 0 con aviso (D2.1); nunca usa un precio
    // capturado en la fila, porque la tabla no guarda precio.
    const valorada = fila.partId != null;
    const precioUnitario = valorada ? (fila.precioUnitario ?? 0) : 0;
    const subtotal = redondear(precioUnitario * cantidad);
    subtotalRefacciones += subtotal;
    desgloseRefacciones.push({
      id: fila.id ?? null,
      descripcion: fila.descripcion ?? null,
      cantidad,
      precioUnitario: redondear(precioUnitario),
      subtotal,
      // Sin precio conocido (fila heredada sin catálogo o catálogo sin
      // precio): el desglose avisa «sin precio registrado» (D2.1).
      aviso: !valorada || fila.precioUnitario == null ? AVISO_SIN_PRECIO : null,
    });
  }

  subtotalManoDeObra = redondear(subtotalManoDeObra);
  subtotalRefacciones = redondear(subtotalRefacciones);

  return {
    subtotalManoDeObra,
    subtotalRefacciones,
    total: redondear(subtotalManoDeObra + subtotalRefacciones),
    desglose: {
      manoDeObra: desgloseManoDeObra,
      refacciones: desgloseRefacciones,
    },
  };
}
