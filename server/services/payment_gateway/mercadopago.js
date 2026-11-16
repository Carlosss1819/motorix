// Integración real de Mercado Pago en sandbox (Sprint 4, D1, CA-7): API REST
// con el `fetch` nativo de Node LTS, sin SDK (regla de no agregar
// dependencias). El access token sale SIEMPRE de variables de entorno y
// nunca se guarda, se registra ni se devuelve en respuestas (RN-14).
import { config } from '../../config/env.js';
import { HttpError } from '../../utils/errors.js';

export const modo = 'sandbox';

const API_BASE = 'https://api.mercadopago.com';

const pad = (valor, largo = 2) => String(valor).padStart(largo, '0');

// Fecha en ISO 8601 con la zona horaria local, como pide Mercado Pago
// (`2026-11-16T12:30:00.000-06:00`), Sprint 5 (R-09).
export function fechaIsoConZona(fecha) {
  const desfaseMinutos = -fecha.getTimezoneOffset();
  const signo = desfaseMinutos >= 0 ? '+' : '-';
  const absoluto = Math.abs(desfaseMinutos);
  return (
    `${fecha.getFullYear()}-${pad(fecha.getMonth() + 1)}-${pad(fecha.getDate())}` +
    `T${pad(fecha.getHours())}:${pad(fecha.getMinutes())}:${pad(fecha.getSeconds())}` +
    `.${pad(fecha.getMilliseconds(), 3)}` +
    `${signo}${pad(Math.floor(absoluto / 60))}:${pad(absoluto % 60)}`
  );
}

// Cuerpo de la preferencia (función pura, sin red). Sprint 5 (FR-037, R-09):
// la preferencia vence a las `vigenciaHoras` de crearse, con
// `expires: true`, `expiration_date_from` = ahora y `expiration_date_to` =
// ahora + vigencia. `monto` es el total de la orden con precio congelado.
export function armarPreferencia({
  orden,
  monto,
  referencia,
  ahora = new Date(),
  vigenciaHoras = config.payments.mpPreferenciaVigenciaHoras,
  urlPublica = config.payments.mpPublicUrl,
}) {
  const vence = new Date(ahora.getTime() + vigenciaHoras * 60 * 60 * 1000);
  return {
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
      success: urlPublica,
      failure: urlPublica,
      pending: urlPublica,
    },
    metadata: { ordenId: orden.id },
    expires: true,
    expiration_date_from: fechaIsoConZona(ahora),
    expiration_date_to: fechaIsoConZona(vence),
  };
}

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
    body: JSON.stringify(armarPreferencia({ orden, monto, referencia })),
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
