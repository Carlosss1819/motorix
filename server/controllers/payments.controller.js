// Controlador de los pagos de las órdenes (Sprint 4, US1).
import * as service from '../services/payment.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

export async function registerPaymentHandler(req, res) {
  sendCreated(res, await service.registerPayment(req.body, req.user));
}

export async function listByOrderHandler(req, res) {
  sendOk(res, await service.listPaymentsByOrderId(Number(req.params.ordenId), req.query));
}

// Total y desglose vigentes de la orden para el formulario de pago (FR-015).
export async function getOrderChargeHandler(req, res) {
  sendOk(res, await service.getOrderCharge(Number(req.params.ordenId)));
}

export async function annulPaymentHandler(req, res) {
  sendOk(res, await service.annulPayment(Number(req.params.id), req.body, req.user));
}

// Confirmación manual de un cobro Mercado Pago pendiente (US3, FR-005).
export async function confirmPaymentHandler(req, res) {
  sendOk(res, await service.confirmPayment(Number(req.params.id), req.body));
}
