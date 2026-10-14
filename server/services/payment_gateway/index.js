// Selección de la pasarela de cobro (Sprint 4, D1): con `MP_ACCESS_TOKEN`
// se usa la integración real de Mercado Pago en sandbox; sin él, la simulada
// (demo y pruebas automatizadas). La elección es fija por proceso, al
// arrancar. Interfaz única: `crearPreferencia(orden, monto, referencia)` →
// `{ idExterno, enlace }`.
import { config } from '../../config/env.js';
import * as mercadopago from './mercadopago.js';
import * as simulado from './simulado.js';

const pasarela = config.payments.mpAccessToken ? mercadopago : simulado;

// Modo del cobro que se guarda en el pago (`sandbox` | `simulado`, D1).
export const modoPasarela = pasarela.modo;

// Crea la preferencia de cobro en la pasarela elegida. Nunca devuelve datos
// de tarjeta ni credenciales (RN-14).
export function crearPreferencia(orden, monto, referencia) {
  return pasarela.crearPreferencia(orden, monto, referencia);
}
