// Reloj del servidor (Sprint 6, ajuste M3): los cálculos que dependen de «hoy»
// o de «ahora» (avisos, estado de mantenimientos) usan esta función en lugar
// de `new Date()` o de `NOW()` en SQL. En las pruebas se fija a una hora
// conocida para que una corrida cerca de la medianoche no cambie el resultado.
let fixedNow = null;

export function now() {
  return fixedNow ? new Date(fixedNow.getTime()) : new Date();
}

// Solo para pruebas (NODE_ENV=test). `null` vuelve al reloj real.
export function setNowForTests(date) {
  if (process.env.NODE_ENV !== 'test') {
    throw new Error('El reloj solo se puede fijar en pruebas');
  }
  fixedNow = date ? new Date(date) : null;
}
