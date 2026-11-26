import '../models/report.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Consulta de `/api/reports/*` (Sprint 7, Entrega B, US4 a US7). Solo ADMIN:
/// el backend responde 403 a los demás roles (FR-038).
class ReportsService {
  ReportsService(this._api);

  final ApiClient _api;

  Map<String, String> _query(ReportRange rango, {String? formato}) => <String, String>{
        'desde': rango.desde,
        'hasta': rango.hasta,
        'formato': ?formato,
      };

  /// `GET /api/reports/<reporte>?desde&hasta`
  Future<ReportView> fetch(ReportKind tipo, ReportRange rango) async {
    final Map<String, dynamic> data =
        asMap(await _api.get('/reports/${tipo.ruta}', query: _query(rango)));
    return ReportView.fromJson(tipo, data);
  }

  /// `GET /api/reports/<reporte>?desde&hasta&formato=csv` — el mismo contenido
  /// que la pantalla, en CSV UTF-8 con BOM (FR-037).
  Future<String> exportCsv(ReportKind tipo, ReportRange rango) =>
      _api.getText('/reports/${tipo.ruta}', query: _query(rango, formato: 'csv'));

  /// Nombre del archivo, igual al que indica el backend.
  static String fileName(ReportKind tipo, ReportRange rango) =>
      '${tipo.ruta}_${rango.desde}_${rango.hasta}.csv';
}
