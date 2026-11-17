import '../models/notification.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones de `/api/notifications` (Sprint 6, contracts/notifications.md).
/// Los avisos se calculan en el servidor y ya vienen filtrados por rol.
class NotificationsService {
  NotificationsService(this._api);

  final ApiClient _api;

  /// GET /api/notifications — avisos agrupados del usuario.
  Future<NotificationsSummary> fetchAll() async {
    final dynamic data = await _api.get('/notifications');
    return NotificationsSummary.fromJson(asMap(data));
  }

  /// GET /api/notifications/count — solo el número de no leídos.
  Future<int> fetchCount() async {
    final dynamic data = await _api.get('/notifications/count');
    return asInt(asMap(data)['noLeidos']);
  }

  /// POST /api/notifications/read — marca el aviso como leído (204).
  Future<void> markRead(String clave) async {
    await _api.post('/notifications/read', body: <String, dynamic>{'clave': clave});
  }
}
