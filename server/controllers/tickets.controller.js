// Controlador de los tickets de servicio (Sprint 4, US4).
import * as service from '../services/ticket.service.js';
import { sendOk, sendCreated } from '../utils/response.js';

// 201 en la primera generación y 200 cuando ya existía (idempotente, HU4-2).
export async function generateTicketHandler(req, res) {
  const { ticket, creado } = await service.generateTicket(
    Number(req.body.ordenId),
    req.user,
  );
  if (creado) {
    sendCreated(res, ticket);
    return;
  }
  sendOk(res, ticket);
}

export async function getTicketHandler(req, res) {
  sendOk(res, await service.getTicket(Number(req.params.id)));
}

export async function getTicketByOrderHandler(req, res) {
  sendOk(res, await service.getTicketByOrder(Number(req.params.ordenId)));
}
