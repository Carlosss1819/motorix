import 'package:flutter/foundation.dart';

import '../models/part.dart';
import '../models/part_movement.dart';
import '../services/api_client.dart';
import '../services/parts_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Estado del detalle de una refacción y de su historial de movimientos
/// (US6/HU6): la refacción con sus datos de catálogo y el historial paginado
/// que explica cada cambio de stock (FR-018, FR-030, patrón R-10).
class PartDetailProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  PartDetailProvider({required ApiClient api, PartsService? service})
      : _service = service ?? PartsService(api);

  /// Movimientos por página en el historial paginado del backend.
  static const int porPagina = 10;

  final PartsService _service;

  LoadStatus _status = LoadStatus.idle;
  Part? _part;
  List<PartMovement> _items = const <PartMovement>[];
  String? _error;
  int _pagina = 1;
  int _paginas = 1;
  int _total = 0;
  int? _partId;

  LoadStatus get status => _status;
  Part? get part => _part;
  List<PartMovement> get items => _items;
  String? get error => _error;
  int get pagina => _pagina;
  int get paginas => _paginas;
  int get total => _total;

  bool get isLoading => _status == LoadStatus.loading;

  /// Carga la refacción y la primera página de su historial.
  Future<void> load(int partId) async {
    _partId = partId;
    _pagina = 1;
    await _fetch();
  }

  /// Vuelve a cargar con la página actual.
  Future<void> reload() => _fetch();

  /// Cambia de página del historial de movimientos.
  Future<void> goToPage(int value) async {
    final int destino = value.clamp(1, _paginas);
    if (destino == _pagina) {
      return;
    }
    _pagina = destino;
    await _fetch();
  }

  /// Limpia el detalle cargado para no mostrar datos de otra pantalla.
  void clear() {
    _part = null;
    _items = const <PartMovement>[];
    _status = LoadStatus.idle;
    _error = null;
    _pagina = 1;
    _paginas = 1;
    _total = 0;
    _partId = null;
  }

  Future<void> _fetch() async {
    final int? partId = _partId;
    if (partId == null) {
      return;
    }
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      // Refacción y movimientos viajan juntos: si uno falla, la pantalla
      // muestra el error completo en lugar de datos a medias.
      final Part part = await _service.detail(partId);
      final PartMovementPage page = await _service.movements(
        partId: partId,
        pagina: _pagina,
        porPagina: porPagina,
      );
      _part = part;
      _items = page.elementos;
      _pagina = page.pagina;
      _paginas = page.paginas;
      _total = page.total;
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _part = null;
      _items = const <PartMovement>[];
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _part = null;
      _items = const <PartMovement>[];
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }
}
