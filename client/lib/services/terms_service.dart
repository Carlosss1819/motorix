import '../models/terms.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones de `/api/terms` (Sprint 7, US9). `current` y `accept` se
/// pueden usar con la aceptación pendiente; la lista de aceptaciones es solo
/// de ADMIN (el backend lo valida).
class TermsService {
  TermsService(this._api);

  final ApiClient _api;

  /// GET /api/terms/current
  Future<TermsVersion> current() async {
    final dynamic data = await _api.get('/terms/current');
    return TermsVersion.fromJson(asMap(data));
  }

  /// POST /api/terms/accept (idempotente).
  Future<void> accept(String version) async {
    await _api.post('/terms/accept', body: <String, dynamic>{'version': version});
  }

  /// GET /api/terms/acceptances (ADMIN).
  Future<PagedResult<TermsAcceptance>> acceptances({int pagina = 1}) async {
    final Map<String, dynamic> data = asMap(
      await _api.get(
        '/terms/acceptances',
        query: <String, String>{'pagina': '$pagina', 'porPagina': '20'},
      ),
    );
    return PagedResult<TermsAcceptance>(
      elementos:
          asList(data['elementos']).map(TermsAcceptance.fromJson).toList(),
      pagina: asInt(data['pagina'], 1),
      paginas: asInt(data['paginas'], 1),
      total: asInt(data['total']),
    );
  }
}
