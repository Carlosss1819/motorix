import '../models/vehicle_history.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones del historial del vehículo (US1): consulta derivada de las
/// órdenes terminadas. Contrato: contracts/history.md.
class VehicleHistoryService {
  VehicleHistoryService(this._api);

  final ApiClient _api;

  /// GET /api/vehicles/:id/history?pagina=&porPagina=
  Future<HistoryPage> list({
    required int vehicleId,
    int pagina = 1,
    int porPagina = 10,
  }) async {
    final dynamic data = await _api.get(
      '/vehicles/$vehicleId/history',
      query: <String, String>{
        'pagina': '$pagina',
        'porPagina': '$porPagina',
      },
    );
    return HistoryPage.fromJson(asMap(data));
  }
}
