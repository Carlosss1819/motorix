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

  /// GET /api/service-orders?estadoAbierta=true (R-09): las órdenes que siguen
  /// en el taller, para el panel de recepción (US6).
  Future<ServiceOrderPage> listOpen({int pagina = 1, int porPagina = 10}) async {
    final dynamic data = await _api.get(
      '/service-orders',
      query: <String, String>{
        'buscar': '',
        'estado': '',
        'estadoAbierta': 'true',
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

  /// POST /api/service-orders/:id/diagnostico. `borrador` deja el texto sin
  /// confirmar (FR-011) y el backend rechaza con `409` las órdenes
  /// entregadas (FR-016).
  Future<void> saveDiagnosis({
    required int id,
    required String texto,
    required bool borrador,
  }) async {
    await _api.post(
      '/service-orders/$id/diagnostico',
      body: <String, dynamic>{'texto': texto, 'borrador': borrador},
    );
  }

  /// POST /api/service-orders/:id/servicios: crea el servicio con su partida
  /// de mano de obra en la misma transacción (FR-012, R-13).
  Future<void> addService({
    required int id,
    required String descripcion,
    required int duracionMinutos,
    num? precio,
  }) async {
    await _api.post(
      '/service-orders/$id/servicios',
      body: <String, dynamic>{
        'descripcion': descripcion,
        'duracionMinutos': duracionMinutos,
        'precio': ?precio,
      },
    );
  }

  /// DELETE /api/service-orders/:id/servicios/:servicioId: baja del servicio
  /// con la mano de obra asociada (el backend responde `409` si la orden ya
  /// fue entregada, FR-016).
  Future<void> removeService({
    required int id,
    required int servicioId,
  }) async {
    await _api.delete('/service-orders/$id/servicios/$servicioId');
  }

  /// POST /api/service-orders/:id/repuestos: solo registra el repuesto junto
  /// a la orden; el inventario se valida en el Sprint 3 (RN-06).
  Future<void> addPart({
    required int id,
    required String descripcion,
    required int cantidad,
  }) async {
    await _api.post(
      '/service-orders/$id/repuestos',
      body: <String, dynamic>{'descripcion': descripcion, 'cantidad': cantidad},
    );
  }

  /// DELETE /api/service-orders/:id/repuestos/:repuestoId.
  Future<void> removePart({
    required int id,
    required int repuestoId,
  }) async {
    await _api.delete('/service-orders/$id/repuestos/$repuestoId');
  }

  /// POST /api/service-orders/:id/recomendaciones: recomendaciones para la
  /// entrega (FR-013).
  Future<void> saveRecommendations({
    required int id,
    required String texto,
  }) async {
    await _api.post(
      '/service-orders/$id/recomendaciones',
      body: <String, dynamic>{'texto': texto},
    );
  }

  /// POST /api/service-orders/:id/estado: transición del mapa R-02 con los
  /// permisos por rol R-03 / FR-022; el backend responde `403` fuera de rol
  /// y `409` con los estados permitidos cuando la transición es inválida.
  Future<void> changeStatus({
    required int id,
    required String estado,
    String? nota,
  }) async {
    await _api.post(
      '/service-orders/$id/estado',
      body: <String, dynamic>{'estado': estado, 'nota': ?nota},
    );
  }
}
