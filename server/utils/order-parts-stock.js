// Reglas puras del stock de las refacciones usadas en una orden (US7,
// Sprint 3): cálculo del `stock_after`, rechazo de cantidades inválidas y
// validación de existencias (RN-8, FR-025, R-08). Es un módulo sin base de
// datos para poder probarlo en unidad, al estilo de order-transitions.js.
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
//
// La validación de existencias se ejecuta SIEMPRE dentro de la transacción
// que ya bloqueó la fila con `SELECT … FOR UPDATE`: si no alcanza, el
// llamador hace `ROLLBACK` y responde con el resultado que devuelve aquí.

// Una cantidad válida es un entero mayor o igual a 1 (FR-025, RN-6).
export function evaluateQuantity(cantidad) {
  if (!Number.isInteger(cantidad) || cantidad < 1) {
    return {
      valida: false,
      httpStatus: 400,
      codigo: 'CANTIDAD_INVALIDA',
      mensaje: 'La cantidad debe ser un número entero mayor o igual a 1',
    };
  }
  return { valida: true };
}

// Stock que queda después de usar la cantidad en la orden. Puede ser
// negativo: ese valor es el que detecta `evaluateStock` (RN-8).
export function computeStockAfter(stockActual, cantidad) {
  return stockActual - cantidad;
}

// Existencias suficientes para la cantidad pedida. Un stock resultante en 0
// es válido: el stock nunca puede quedar por debajo de 0 (RN-8).
export function evaluateStock(stockActual, cantidad) {
  const stockAfter = computeStockAfter(stockActual, cantidad);
  if (stockAfter < 0) {
    return {
      suficiente: false,
      stockAfter,
      httpStatus: 409,
      codigo: 'STOCK_INSUFICIENTE',
      mensaje:
        `Stock insuficiente: la refacción tiene ${stockActual} unidades ` +
        `y se solicitaban ${cantidad}`,
    };
  }
  return { suficiente: true, stockAfter };
}
