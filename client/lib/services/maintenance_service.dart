import '../models/maintenance.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones del recurso `/api/maintenance` (US3/US4; contrato:
/// contracts/maintenance.md).
class MaintenanceService {
  MaintenanceService(this._api);

  final ApiClient _api;

  /// GET /api/maintenance?vehiculoId=&estado=&buscar=&pagina=&porPagina=
  Future<MaintenancePage> list({
    int? vehiculoId,
    String estado = '',
    String buscar = '',
    int pagina = 1,
    int porPagina = 10,
  }) async {
    final dynamic data = await _api.get(
      '/maintenance',
      query: <String, String>{
        if (vehiculoId != null) 'vehiculoId': '$vehiculoId',
        'estado': estado,
        'buscar': buscar,
        'pagina': '$pagina',
        'porPagina': '$porPagina',
      },
    );
    return MaintenancePage.fromJson(asMap(data));
  }

  /// GET /api/maintenance/:id
  Future<Maintenance> detail(int id) async {
    final dynamic data = await _api.get('/maintenance/$id');
    return Maintenance.fromJson(asMap(data));
  }

  /// POST /api/maintenance: al menos un objetivo es obligatorio
  /// (`fechaObjetivo` o `kilometrajeObjetivo`, FR-009).
  Future<Maintenance> create({
    required int vehiculoId,
    required String tipoServicio,
    String? fechaObjetivo,
    int? kilometrajeObjetivo,
    int? intervaloDias,
    int? intervaloKm,
    int? antelacionDias,
    int? antelacionKm,
    String? notas,
  }) async {
    final dynamic data = await _api.post(
      '/maintenance',
      body: <String, Object?>{
        'vehiculoId': vehiculoId,
        'tipoServicio': tipoServicio,
        if (fechaObjetivo != null && fechaObjetivo.isNotEmpty)
          'fechaObjetivo': fechaObjetivo,
        if (kilometrajeObjetivo != null) 'kilometrajeObjetivo': kilometrajeObjetivo,
        if (intervaloDias != null) 'intervaloDias': intervaloDias,
        if (intervaloKm != null) 'intervaloKm': intervaloKm,
        if (antelacionDias != null) 'antelacionDias': antelacionDias,
        if (antelacionKm != null) 'antelacionKm': antelacionKm,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      },
    );
    return Maintenance.fromJson(asMap(data));
  }

  /// PUT /api/maintenance/:id: actualización parcial.
  Future<Maintenance> update({
    required int id,
    required String tipoServicio,
    String? fechaObjetivo,
    int? kilometrajeObjetivo,
    int? intervaloDias,
    int? intervaloKm,
    int? antelacionDias,
    int? antelacionKm,
    String? notas,
  }) async {
    final dynamic data = await _api.put(
      '/maintenance/$id',
      body: <String, Object?>{
        'tipoServicio': tipoServicio,
        if (fechaObjetivo != null && fechaObjetivo.isNotEmpty)
          'fechaObjetivo': fechaObjetivo,
        if (kilometrajeObjetivo != null) 'kilometrajeObjetivo': kilometrajeObjetivo,
        if (intervaloDias != null) 'intervaloDias': intervaloDias,
        if (intervaloKm != null) 'intervaloKm': intervaloKm,
        if (antelacionDias != null) 'antelacionDias': antelacionDias,
        if (antelacionKm != null) 'antelacionKm': antelacionKm,
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      },
    );
    return Maintenance.fromJson(asMap(data));
  }

  /// POST /api/maintenance/:id/realizar (FR-015): renueva el mismo registro.
  /// Sin parámetros usa hoy y el kilometraje vigente del vehículo.
  Future<Maintenance> realizar(
    int id, {
    String? fechaServicio,
    int? kilometrajeServicio,
  }) async {
    final dynamic data = await _api.post(
      '/maintenance/$id/realizar',
      body: <String, Object?>{
        if (fechaServicio != null && fechaServicio.isNotEmpty)
          'fechaServicio': fechaServicio,
        if (kilometrajeServicio != null)
          'kilometrajeServicio': kilometrajeServicio,
      },
    );
    return Maintenance.fromJson(asMap(data));
  }
}
