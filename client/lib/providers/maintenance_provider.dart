import 'package:flutter/foundation.dart';

import '../models/maintenance.dart';
import '../services/api_client.dart';
import '../services/maintenance_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Filtro «sin estado» del listado de mantenimientos.
const String kTodosLosEstadosMantenimiento = '';

/// Estado del listado y del formulario de mantenimientos (US3/US4).
class MaintenanceProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  MaintenanceProvider({required ApiClient api, MaintenanceService? service})
      : _service = service ?? MaintenanceService(api);

  /// Mantenimientos por página en el listado paginado del backend.
  static const int porPagina = 10;

  final MaintenanceService _service;

  LoadStatus _status = LoadStatus.idle;
  List<Maintenance> _items = const <Maintenance>[];
  String? _error;
  String _buscar = '';
  String _estado = kTodosLosEstadosMantenimiento;
  int _pagina = 1;
  int _paginas = 1;
  int _total = 0;
  int? _vehicleId;

  LoadStatus get status => _status;
  List<Maintenance> get items => _items;
  String? get error => _error;
  String get buscar => _buscar;
  String get estado => _estado;
  int get pagina => _pagina;
  int get paginas => _paginas;
  int get total => _total;

  bool get isLoading => _status == LoadStatus.loading;

  /// Carga el listado con los filtros actuales.
  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final MaintenancePage page = await _service.list(
        vehiculoId: _vehicleId,
        estado: _estado,
        buscar: _buscar,
        pagina: _pagina,
        porPagina: porPagina,
      );
      _items = page.elementos;
      _pagina = page.pagina;
      _paginas = page.paginas;
      _total = page.total;
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _items = const <Maintenance>[];
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _items = const <Maintenance>[];
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Vuelve a cargar con los últimos filtros usados.
  Future<void> reload() => load();

  /// Filtra por estado calculado, desde la primera página.
  Future<void> setEstado(String value) async {
    if (_estado == value) {
      return;
    }
    _estado = value;
    _pagina = 1;
    await load();
  }

  /// Filtra por tipo de servicio o placas (HU4), desde la primera página.
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

  /// Limpia los filtros (por ejemplo al salir de la pantalla).
  void clear() {
    _items = const <Maintenance>[];
    _status = LoadStatus.idle;
    _error = null;
    _buscar = '';
    _estado = kTodosLosEstadosMantenimiento;
    _pagina = 1;
    _paginas = 1;
    _total = 0;
    _vehicleId = null;
  }

  /// Registra un mantenimiento y refresca el listado. Lanza [ApiException]
  /// con el `409` de duplicado o el `400 OBJETIVO_REQUERIDO`.
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
    final Maintenance created = await _service.create(
      vehiculoId: vehiculoId,
      tipoServicio: tipoServicio,
      fechaObjetivo: fechaObjetivo,
      kilometrajeObjetivo: kilometrajeObjetivo,
      intervaloDias: intervaloDias,
      intervaloKm: intervaloKm,
      antelacionDias: antelacionDias,
      antelacionKm: antelacionKm,
      notas: notas,
    );
    await reload();
    return created;
  }

  /// Edita un mantenimiento y refresca el listado.
  Future<Maintenance> update({
    required int id,
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
    final Maintenance updated = await _service.update(
      id: id,
      tipoServicio: tipoServicio,
      fechaObjetivo: fechaObjetivo,
      kilometrajeObjetivo: kilometrajeObjetivo,
      intervaloDias: intervaloDias,
      intervaloKm: intervaloKm,
      antelacionDias: antelacionDias,
      antelacionKm: antelacionKm,
      notas: notas,
    );
    await reload();
    return updated;
  }

  /// Marca «servicio realizado» (FR-015): el backend renueva el mismo
  /// registro. Lanza [ApiException] con el `400` de kilometraje sin corrección.
  Future<Maintenance> realizar(int id) async {
    final Maintenance renovado = await _service.realizar(id);
    await reload();
    return renovado;
  }
}
