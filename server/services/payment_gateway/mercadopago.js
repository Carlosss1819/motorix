// Integración real de Mercado Pago en sandbox (Sprint 4, D1, CA-7): API REST
// con el `fetch` nativo de Node LTS, sin SDK (regla de no agregar
// dependencias). El access token sale SIEMPRE de variables de entorno y
// nunca se guarda, se registra ni se devuelve en respuestas (RN-14).
import { config } from '../../config/env.js';
import { HttpError } from '../../utils/errors.js';

export const modo = 'sandbox';

const API_BASE = 'https://api.mercadopago.com';

// Interfaz única de la pasarela: `crearPreferencia(orden, monto, referencia)`
// → `{ idExterno, enlace }`. `referencia` viaja como `external_reference`
// para poder correlacionar el cobro con la orden sin exponer el token.
export async function crearPreferencia(orden, monto, referencia) {
  const respuesta = await fetch(`${API_BASE}/checkout/preferences`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.payments.mpAccessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      items: [
        {
          id: `orden-${orden.id}`,
          title: `Orden de servicio #${orden.id}`,
          quantity: 1,
          unit_price: Number(monto),
          currency_id: 'MXN',
        },
      ],
      external_reference: referencia,
      back_urls: {
        success: config.payments.mpPublicUrl,
        failure: config.payments.mpPublicUrl,
        pending: config.payments.mpPublicUrl,
      },
      metadata: { ordenId: orden.id },
    }),
  });

  if (!respuesta.ok) {
    // El detalle del proveedor no se expone: solo un aviso claro y reintentable.
    throw new HttpError(
      502,
      'No se pudo iniciar el cobro con Mercado Pago: intenta de nuevo',
      'GATEWAY_ERROR',
    );
  }

  const preferencia = await respuesta.json();
  return { idExterno: referencia, enlace: preferencia.init_point };
}
