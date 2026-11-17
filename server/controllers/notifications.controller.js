// Controladores de los avisos internos (Sprint 6).
import { countUnread, getNotifications, markRead } from '../services/notification.service.js';
import { sendNoContent, sendOk } from '../utils/response.js';

export async function listNotificationsHandler(req, res) {
  sendOk(res, await getNotifications(req.user));
}

export async function countNotificationsHandler(req, res) {
  sendOk(res, await countUnread(req.user));
}

export async function markReadHandler(req, res) {
  await markRead(req.user, req.body.clave);
  sendNoContent(res);
}
