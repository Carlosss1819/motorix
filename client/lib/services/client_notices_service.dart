import '../models/client_notice.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones de `/api/client-notices` (Sprint 6, US7). Solo ADMIN y
/// RECEPTIONIST; el backend responde 403 al mecánico (FR-022).
class ClientNoticesService {
  ClientNoticesService(this._api);

  final ApiClient _api;

  /// GET /api/client-notices — clientes por avisar, ya ordenados (FR-029).
  Future<List<ClientNotice>> fetchAll() async {
    final dynamic data = await _api.get('/client-notices');
    return asList(asMap(data)['elementos']).map(ClientNotice.fromJson).toList();
  }

  /// POST /api/client-notices — registra que se avisó al cliente (201).
  /// 409 `YA_AVISADO` y 404 `HECHO_NO_VIGENTE` llegan como [ApiException].
  Future<void> markNotified(String clave) async {
    await _api.post('/client-notices', body: <String, dynamic>{'clave': clave});
  }
}
