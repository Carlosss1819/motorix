import '../models/service_order.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones del recurso `/api/service-orders` (US1; contrato:
/// contracts/service-orders.md).
class ServiceOrdersService {
  ServiceOrdersService(this._api);

  final ApiClient _api;

  /// GET /api/service-orders?buscar=&estado=&pagina=&porPagina=
  ///
  /// La búsqueda cubre placas y nombre o apellido del cliente (FR-003).
  Future<ServiceOrderPage> list({
    String buscar = '',
    String estado = '',
    int pagina = 1,
    int porPagina = 10,
  }) async {
    final dynamic data = await _api.get(
      '/service-orders',
      query: <String, String>{
        'buscar': buscar,
        'estado': estado,
        'pagina': '$pagina',
        'porPagina': '$porPagina',
      },
    );
    return ServiceOrderPage.fromJson(asMap(data));
  }

  /// GET /api/service-orders/:id, con servicios, repuestos e historial.
  Future<ServiceOrder> detail(int id) async {
    final dynamic data = await _api.get('/service-orders/$id');
    return ServiceOrder.fromJson(asMap(data));
  }

  /// POST /api/service-orders. El vehículo debe pertenecer al cliente elegido
  /// (RN-02) y la orden nace siempre en estado `RECIBIDO` (FR-014). Con
  /// [citaId] la orden deriva de una cita `RECIBIDA` (FR-007).
  Future<ServiceOrder> create({
    required int clienteId,
    required int vehiculoId,
    required String motivoVisita,
    required String fechaIngreso,
    required int kilometraje,
    int? citaId,
  }) async {
    final dynamic data = await _api.post(
      '/service-orders',
      body: <String, dynamic>{
        'clienteId': clienteId,
        'vehiculoId': vehiculoId,
        'motivoVisita': motivoVisita,
        'fechaIngreso': fechaIngreso,
        'kilometraje': kilometraje,
        'citaId': ?citaId,
      },
    );
    return ServiceOrder.fromJson(asMap(data));
  }

  /// PUT /api/service-orders/:id. No cambia cliente ni vehículo, no aplica a
  /// órdenes terminadas ni entregadas y respeta la regla de kilometraje (R-08).
  Future<ServiceOrder> update({
    required int id,
    required String motivoVisita,
    required String fechaIngreso,
    required int kilometraje,
    String? correccionKilometraje,
  }) async {
    final dynamic data = await _api.put(
      '/service-orders/$id',
      body: <String, dynamic>{
        'motivoVisita': motivoVisita,
        'fechaIngreso': fechaIngreso,
        'kilometraje': kilometraje,
        if (correccionKilometraje != null &&
            correccionKilometraje.isNotEmpty)
          'correccionKilometraje': correccionKilometraje,
      },
    );
    return ServiceOrder.fromJson(asMap(data));
  }

  /// POST /api/service-orders/:id/asignar. `mecanicoId` nulo desasigna la
  /// orden; el backend responde `409` si la orden está cerrada (FR-009).
  Future<AssignedMechanic> assign({
    required int id,
    required int? mecanicoId,
  }) async {
    final dynamic data = await _api.post(
      '/service-orders/$id/asignar',
      body: <String, dynamic>{'mecanicoId': mecanicoId},
    );
    return AssignedMechanic.fromJson(asMap(data));
  }

  /// GET /api/users/mechanics: mecánicos activos para la asignación (FR-009).
  Future<List<MechanicOption>> listMechanics() async {
    final dynamic data = await _api.get('/users/mechanics');
    return asList(data).map(MechanicOption.fromJson).toList();
  }
}
