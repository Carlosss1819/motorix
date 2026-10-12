import 'package:flutter/foundation.dart';

import '../models/client.dart';
import '../services/api_client.dart';
import '../services/clients_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Estado de la lista y del detalle de clientes (US3 y US4).
class ClientsProvider extends ChangeNotifier {
  ClientsProvider({required ApiClient api}) : _service = ClientsService(api);

  final ClientsService _service;

  LoadStatus _status = LoadStatus.idle;
  List<Client> _items = const <Client>[];
  String? _error;
  String _buscar = '';

  LoadStatus _detailStatus = LoadStatus.idle;
  Client? _selected;
  String? _detailError;

  LoadStatus get status => _status;
  List<Client> get items => _items;
  String? get error => _error;
  String get buscar => _buscar;

  LoadStatus get detailStatus => _detailStatus;
  Client? get selected => _selected;
  String? get detailError => _detailError;

  bool get isLoading => _status == LoadStatus.loading;
  bool get isDetailLoading => _detailStatus == LoadStatus.loading;

  /// Carga la lista con el texto de búsqueda indicado.
  Future<void> load({String? buscar}) async {
    if (buscar != null) {
      _buscar = buscar;
    }
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _items = await _service.list(buscar: _buscar);
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _items = const <Client>[];
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _items = const <Client>[];
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Vuelve a cargar con la última búsqueda usada.
  Future<void> reload() => load();

  /// Carga la ficha de un cliente con sus vehículos asociados.
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

  /// Limpia la ficha cargada para que no se muestre datos de otra pantalla.
  void clearDetail() {
    _selected = null;
    _detailStatus = LoadStatus.idle;
    _detailError = null;
  }

  /// Registra un cliente. Si el teléfono está repetido, devuelve un aviso que
  /// obliga a confirmar antes de reenviar.
  Future<ClientCreateResult> create({
    required String nombre,
    required String telefono,
    String? email,
    bool confirmar = false,
  }) async {
    final ClientCreateResult result = await _service.create(
      nombre: nombre,
      telefono: telefono,
      email: email,
      confirmar: confirmar,
    );
    if (!result.needsConfirmation) {
      await reload();
    }
    return result;
  }

  /// Edita un cliente conservando sus vehículos asociados (FR-015).
  Future<Client> update({
    required int id,
    required String nombre,
    required String telefono,
    String? email,
  }) async {
    final Client updated = await _service.update(
      id: id,
      nombre: nombre,
      telefono: telefono,
      email: email,
    );
    await reload();
    return updated;
  }
}
