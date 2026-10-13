import 'package:flutter/foundation.dart';

import '../models/service_order.dart';
import '../services/api_client.dart';
import '../services/service_orders_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Filtro "sin estado", para el selector de la lista de órdenes.
const String kTodosLosEstados = '';

/// Estado de la lista y de la ficha de las órdenes de servicio (US1).
class ServiceOrdersProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  ServiceOrdersProvider({required ApiClient api, ServiceOrdersService? service})
      : _service = service ?? ServiceOrdersService(api);

  /// Órdenes por página en el listado paginado del backend.
  static const int porPagina = 10;

  final ServiceOrdersService _service;

  LoadStatus _status = LoadStatus.idle;
  List<ServiceOrder> _items = const <ServiceOrder>[];
  String? _error;
  String _buscar = '';
  String _estado = kTodosLosEstados;
  int _pagina = 1;
  int _paginas = 1;
  int _total = 0;

  LoadStatus _detailStatus = LoadStatus.idle;
  ServiceOrder? _selected;
  String? _detailError;

  LoadStatus get status => _status;
  List<ServiceOrder> get items => _items;
  String? get error => _error;
  String get buscar => _buscar;
  String get estado => _estado;
  int get pagina => _pagina;
  int get paginas => _paginas;
  int get total => _total;

  LoadStatus get detailStatus => _detailStatus;
  ServiceOrder? get selected => _selected;
  String? get detailError => _detailError;

  bool get isLoading => _status == LoadStatus.loading;
  bool get isDetailLoading => _detailStatus == LoadStatus.loading;

  /// Carga la página actual con los filtros aplicados (buscar y estado).
  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final ServiceOrderPage page = await _service.list(
        buscar: _buscar,
        estado: _estado,
        pagina: _pagina,
        porPagina: porPagina,
      );
      _items = page.elementos;
      _pagina = page.pagina;
      _paginas = page.paginas;
      _total = page.total;
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _items = const <ServiceOrder>[];
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _items = const <ServiceOrder>[];
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Vuelve a cargar con los últimos filtros usados.
  Future<void> reload() => load();

  /// Filtra por estado de orden siempre desde la primera página.
  Future<void> setEstado(String value) async {
    if (_estado == value) {
      return;
    }
    _estado = value;
    _pagina = 1;
    await load();
  }

  /// Filtra por placas o nombre del cliente (FR-003), desde la primera página.
  Future<void> setBuscar(String value) async {
    if (_buscar == value) {
      return;
    }
    _buscar = value;
    _pagina = 1;
    await load();
  }

  /// Cambia de página del listado.
  Future<void> goToPage(int value) async {
    final int destino = value.clamp(1, _paginas);
    if (destino == _pagina) {
      return;
    }
    _pagina = destino;
    await load();
  }

  /// Carga la ficha completa de una orden, con servicios, repuestos e historial.
  Future<void> loadDetail(int id) async {
    _detailStatus = LoadStatus.loading;
    _selected = null;
    _detailError = null;
    notifyListeners();

    try {
      _selected = await _service.detail(id);
      _detailStatus = LoadStatus.ready;
    } on ApiException catch (e) {
      _detailError = e.mensaje;
      _detailStatus = LoadStatus.error;
    } catch (_) {
      _detailError = AppMessages.unexpectedError;
      _detailStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Limpia la ficha cargada para no mostrar datos de otra pantalla.
  void clearDetail() {
    _selected = null;
    _detailStatus = LoadStatus.idle;
    _detailError = null;
  }

  /// Registra una orden de servicio (nace en `RECIBIDO`, FR-014) y refresca
  /// el listado. Con [citaId] deriva de una cita recibida (FR-007).
  Future<ServiceOrder> create({
    required int clienteId,
    required int vehiculoId,
    required String motivoVisita,
    required String fechaIngreso,
    required int kilometraje,
    int? citaId,
  }) async {
    final ServiceOrder created = await _service.create(
      clienteId: clienteId,
      vehiculoId: vehiculoId,
      motivoVisita: motivoVisita,
      fechaIngreso: fechaIngreso,
      kilometraje: kilometraje,
      citaId: citaId,
    );
    _pagina = 1;
    await reload();
    return created;
  }

  /// Edita motivo, fecha y kilometraje de una orden abierta y refresca el
  /// listado y la ficha si estaban cargados.
  Future<ServiceOrder> update({
    required int id,
    required String motivoVisita,
    required String fechaIngreso,
    required int kilometraje,
  }) async {
    final ServiceOrder updated = await _service.update(
      id: id,
      motivoVisita: motivoVisita,
      fechaIngreso: fechaIngreso,
      kilometraje: kilometraje,
    );
    if (_selected?.id == id) {
      _selected = updated;
      notifyListeners();
    }
    await reload();
    return updated;
  }

  /// Asigna o desasigna el mecánico de la orden (FR-009) y refresca el
  /// listado y la ficha. Lanza [ApiException] con el mensaje del backend
  /// (p. ej. el `409` de una orden terminada o entregada).
  Future<AssignedMechanic> assign({
    required int id,
    required int? mecanicoId,
  }) async {
    final AssignedMechanic assigned = await _service.assign(
      id: id,
      mecanicoId: mecanicoId,
    );
    if (_selected?.id == id) {
      _selected = await _service.detail(id);
      notifyListeners();
    }
    await reload();
    return assigned;
  }

  /// Lista los mecánicos activos para el selector de asignación (FR-009).
  Future<List<MechanicOption>> loadMechanics() => _service.listMechanics();

  /// Refresca la ficha (si está cargada) y el listado después de cambiar el
  /// contenido de la orden.
  Future<void> _refrescarContenido(int id) async {
    if (_selected?.id == id) {
      _selected = await _service.detail(id);
      notifyListeners();
    }
    await reload();
  }

  /// Guarda el diagnóstico (FR-011); con `borrador` queda sin confirmar y lo
  /// que no se guarda se descarta en el cliente (FR-019). Lanza
  /// [ApiException] con el `409` de una orden entregada (FR-016).
  Future<void> saveDiagnosis({
    required int id,
    required String texto,
    required bool borrador,
  }) async {
    await _service.saveDiagnosis(id: id, texto: texto, borrador: borrador);
    await _refrescarContenido(id);
  }

  /// Agrega un servicio con su mano de obra en la misma transacción (R-13).
  Future<void> addService({
    required int id,
    required String descripcion,
    required int duracionMinutos,
    num? precio,
  }) async {
    await _service.addService(
      id: id,
      descripcion: descripcion,
      duracionMinutos: duracionMinutos,
      precio: precio,
    );
    await _refrescarContenido(id);
  }

  /// Elimina un servicio de la orden con confirmación previa en la interfaz.
  Future<void> removeService({
    required int id,
    required int servicioId,
  }) async {
    await _service.removeService(id: id, servicioId: servicioId);
    await _refrescarContenido(id);
  }

  /// Registra un repuesto usado en la orden, sin tocar el inventario (RN-06).
  Future<void> addPart({
    required int id,
    required String descripcion,
    required int cantidad,
  }) async {
    await _service.addPart(id: id, descripcion: descripcion, cantidad: cantidad);
    await _refrescarContenido(id);
  }

  /// Elimina un repuesto registrado en la orden.
  Future<void> removePart({
    required int id,
    required int repuestoId,
  }) async {
    await _service.removePart(id: id, repuestoId: repuestoId);
    await _refrescarContenido(id);
  }

  /// Guarda las recomendaciones para la entrega (FR-013).
  Future<void> saveRecommendations({
    required int id,
    required String texto,
  }) async {
    await _service.saveRecommendations(id: id, texto: texto);
    await _refrescarContenido(id);
  }
}
