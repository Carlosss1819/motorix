import '../models/audit_entry.dart';
import '../models/terms.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Filtros de la bitácora (todos opcionales).
class AuditFilters {
  const AuditFilters({this.desde, this.hasta, this.usuarioId, this.accion});

  final String? desde;
  final String? hasta;
  final int? usuarioId;
  final String? accion;
}

/// Consulta de `/api/audit-log` (Sprint 7, US10). Solo ADMIN y solo lectura.
class AuditService {
  AuditService(this._api);

  final ApiClient _api;

  /// Acciones válidas que devuelve el backend junto con la página.
  List<String> acciones = const <String>[];

  /// GET /api/audit-log
  Future<PagedResult<AuditEntry>> list({
    AuditFilters filtros = const AuditFilters(),
    int pagina = 1,
  }) async {
    final Map<String, dynamic> data = asMap(
      await _api.get(
        '/audit-log',
        query: <String, String>{
          'pagina': '$pagina',
          'porPagina': '20',
          if (filtros.desde != null) 'desde': filtros.desde!,
          if (filtros.hasta != null) 'hasta': filtros.hasta!,
          if (filtros.usuarioId != null) 'usuarioId': '${filtros.usuarioId}',
          if (filtros.accion != null) 'accion': filtros.accion!,
        },
      ),
    );
    final List<dynamic> crudas = data['acciones'] is List<dynamic>
        ? data['acciones'] as List<dynamic>
        : const <dynamic>[];
    acciones = crudas.map((dynamic e) => e.toString()).toList();
    return PagedResult<AuditEntry>(
      elementos: asList(data['elementos']).map(AuditEntry.fromJson).toList(),
      pagina: asInt(data['pagina'], 1),
      paginas: asInt(data['paginas'], 1),
      total: asInt(data['total']),
    );
  }
}
