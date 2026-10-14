// Pasarela simulada (Sprint 4, D1): respaldo local que genera un enlace de
// prueba y un id externo ficticio para entornos sin credenciales de Mercado
// Pago (demo y pruebas automatizadas). No abre ninguna conexión ni guarda
// datos sensibles (RN-14).
export const modo = 'simulado';

// Interfaz única de la pasarela: `crearPreferencia(orden, monto, referencia)`
// → `{ idExterno, enlace }`. El id externo se distingue con el prefijo `SIM`
// para que en el historial se vea que el cobro fue simulado.
export async function crearPreferencia(orden, monto, referencia) {
  return {
    idExterno: `SIM-${referencia}`,
    enlace:
      'https://sandbox.mercadopago.com.mx/motorix/checkout/v1/redirect' +
      `?preference=${referencia}&monto=${Number(monto)}`,
  };
}
