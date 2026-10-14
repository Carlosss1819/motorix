import '../models/dashboard_summary.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operación del recurso `/api/dashboard` (HU5; contrato:
/// contracts/dashboard.md). Ruta exclusiva de ADMIN: el backend responde
/// `403 PANEL_SOLO_ADMIN` a otros roles (RN-15) y `400 VALIDACION` si la
/// fecha no tiene formato `AAAA-MM-DD`.
class DashboardService {
  DashboardService(this._api);

  final ApiClient _api;

  /// GET /api/dashboard — resumen del panel; [fecha] es el día de referencia
  /// opcional (`AAAA-MM-DD`), por defecto la fecha actual del backend.
  Future<DashboardSummary> fetchSummary({String? fecha}) async {
    final String ruta = fecha == null || fecha.isEmpty
        ? '/dashboard'
        : '/dashboard?fecha=${Uri.encodeQueryComponent(fecha)}';
    final dynamic data = await _api.get(ruta);
    return DashboardSummary.fromJson(asMap(data));
  }
}
