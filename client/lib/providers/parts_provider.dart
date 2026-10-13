import 'package:flutter/foundation.dart';

import '../models/part.dart';
import '../services/api_client.dart';
import '../services/parts_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Filtro «sin texto» del catálogo de refacciones.
const String kSinBusquedaRefaccion = '';

/// Estado de la lista y de las acciones del catálogo de refacciones (US5).
class PartsProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  PartsProvider({required ApiClient api, PartsService? service})
      : _service = service ?? PartsService(api);

  /// Refacciones por página en el listado paginado del backend (R-10).
  static const int porPagina = 10;

  final PartsService _service;

  LoadStatus _status = LoadStatus.idle;
  List<Part> _items = const <Part>[];
  String? _error;
  String _buscar = kSinBusquedaRefaccion;
  bool _soloStockBajo = false;
  int _pagina = 1;
  int _paginas = 1;
  int _total = 0;

  LoadStatus get status => _status;
  List<Part> get items => _items;
  String? get error => _error;
  String get buscar => _buscar;
  bool get soloStockBajo => _soloStockBajo;
  int get pagina => _pagina;
  int get paginas => _paginas;
  int get total => _total;

  bool get isLoading => _status == LoadStatus.loading;

  /// Carga la página actual con los filtros aplicados.
  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final PartPage page = await _service.list(
        buscar: _buscar,
        stockBajo: _soloStockBajo,
        pagina: _pagina,
        porPagina: porPagina,
      );
      _items = page.elementos;
      _pagina = page.pagina;
      _paginas = page.paginas;
      _total = page.total;
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _items = const <Part>[];
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _items = const <Part>[];
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Vuelve a cargar con los últimos filtros usados.
  Future<void> reload() => load();

  /// Filtra por nombre o código (FR-018), desde la primera página.
  Future<void> setBuscar(String value) async {
    if (_buscar == value) {
      return;
    }
    _buscar = value;
    _pagina = 1;
    await load();
  }

  /// Muestra solo las alertas de stock bajo (FR-020), desde la primera página.
  Future<void> setSoloStockBajo(bool value) async {
    if (_soloStockBajo == value) {
      return;
    }
    _soloStockBajo = value;
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

  /// Registra una refacción y refresca el listado. Lanza [ApiException] con
  /// el `409 CODIGO_DUPLICADO` del backend (FR-017).
  Future<Part> create({
    required String codigo,
    required String nombre,
    required String categoria,
    String? marca,
    int stockInicial = 0,
    int stockMinimo = 0,
    num? precioCompra,
    num? precioVenta,
  }) async {
    final Part created = await _service.create(
      codigo: codigo,
      nombre: nombre,
      categoria: categoria,
      marca: marca,
      stockInicial: stockInicial,
      stockMinimo: stockMinimo,
      precioCompra: precioCompra,
      precioVenta: precioVenta,
    );
    await reload();
    return created;
  }

  /// Edita el catálogo (sin código ni stock actual, FR-022) y refresca.
  Future<Part> update({
    required int id,
    required String nombre,
    required String categoria,
    String? marca,
    required int stockMinimo,
    num? precioCompra,
    num? precioVenta,
  }) async {
    final Part updated = await _service.update(
      id: id,
      nombre: nombre,
      categoria: categoria,
      marca: marca,
      stockMinimo: stockMinimo,
      precioCompra: precioCompra,
      precioVenta: precioVenta,
    );
    await reload();
    return updated;
  }

  /// Desactiva una refacción (FR-019, idempotente) y refresca el listado.
  Future<void> deactivate(int id) async {
    await _service.deactivate(id);
    await reload();
  }
}
