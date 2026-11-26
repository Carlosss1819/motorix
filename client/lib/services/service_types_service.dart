import '../models/service_type.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Datos del formulario de un tipo de servicio.
class ServiceTypeInput {
  const ServiceTypeInput({
    required this.nombre,
    this.intervaloDias,
    this.intervaloKm,
  });

  final String nombre;
  final int? intervaloDias;
  final int? intervaloKm;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'nombre': nombre,
        'intervaloDias': intervaloDias,
        'intervaloKm': intervaloKm,
      };
}

/// Operaciones de `/api/service-types` (Sprint 7). La lista de activos la
/// consultan los tres roles; la escritura es solo de ADMIN (backend).
class ServiceTypesService {
  ServiceTypesService(this._api);

  final ApiClient _api;

  /// GET /api/service-types (con `incluirInactivos` solo para ADMIN).
  Future<List<ServiceType>> list({bool incluirInactivos = false}) async {
    final dynamic data = await _api.get(
      '/service-types',
      query: incluirInactivos
          ? const <String, String>{'incluirInactivos': 'true'}
          : null,
    );
    return asList(asMap(data)['elementos']).map(ServiceType.fromJson).toList();
  }

  /// POST /api/service-types
  Future<ServiceType> create(ServiceTypeInput input) async {
    final dynamic data = await _api.post('/service-types', body: input.toJson());
    return ServiceType.fromJson(asMap(data));
  }

  /// PUT /api/service-types/:id
  Future<ServiceType> update(int id, ServiceTypeInput input) async {
    final dynamic data =
        await _api.put('/service-types/$id', body: input.toJson());
    return ServiceType.fromJson(asMap(data));
  }

  /// POST /api/service-types/:id/activar | /desactivar
  Future<ServiceType> setActive(int id, {required bool activo}) async {
    final dynamic data = await _api
        .post('/service-types/$id/${activo ? 'activar' : 'desactivar'}');
    return ServiceType.fromJson(asMap(data));
  }
}
