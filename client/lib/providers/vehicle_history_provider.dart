import 'package:flutter/foundation.dart';

import '../models/vehicle_history.dart';
import '../services/api_client.dart';
import '../services/vehicle_history_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Estado del historial de un vehículo (US1): consulta derivada paginada con
/// el patrón R-10.
class VehicleHistoryProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  VehicleHistoryProvider({required ApiClient api, VehicleHistoryService? service})
      : _service = service ?? VehicleHistoryService(api);

  /// Entradas por página en el listado paginado del backend.
  static const int porPagina = 10;

  final VehicleHistoryService _service;

  LoadStatus _status = LoadStatus.idle;
  List<HistoryEntry> _items = const <HistoryEntry>[];
  String? _error;
  int _pagina = 1;
  int _paginas = 1;
  int _total = 0;
  int? _vehicleId;

  LoadStatus get status => _status;
  List<HistoryEntry> get items => _items;
  String? get error => _error;
  int get pagina => _pagina;
  int get paginas => _paginas;
  int get total => _total;

  bool get isLoading => _status == LoadStatus.loading;

  /// Carga el historial del vehículo desde la primera página.
  Future<void> load(int vehicleId) async {
    _vehicleId = vehicleId;
    _pagina = 1;
    await _fetch();
  }

  /// Vuelve a cargar con la página actual.
  Future<void> reload() => _fetch();

  /// Cambia de página del historial.
  Future<void> goToPage(int value) async {
    final int destino = value.clamp(1, _paginas);
    if (destino == _pagina) {
      return;
    }
    _pagina = destino;
    await _fetch();
  }

  /// Limpia el historial cargado para no mostrar datos de otra pantalla.
  void clear() {
    _items = const <HistoryEntry>[];
    _status = LoadStatus.idle;
    _error = null;
    _pagina = 1;
    _paginas = 1;
    _total = 0;
    _vehicleId = null;
  }

  Future<void> _fetch() async {
    final int? vehicleId = _vehicleId;
    if (vehicleId == null) {
      return;
    }
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final HistoryPage page = await _service.list(
        vehicleId: vehicleId,
        pagina: _pagina,
        porPagina: porPagina,
      );
      _items = page.elementos;
      _pagina = page.pagina;
      _paginas = page.paginas;
      _total = page.total;
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _items = const <HistoryEntry>[];
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _items = const <HistoryEntry>[];
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }
}
