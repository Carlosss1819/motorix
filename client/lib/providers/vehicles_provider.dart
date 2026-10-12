import 'package:flutter/foundation.dart';

import '../models/vehicle.dart';
import '../services/api_client.dart';
import '../services/vehicles_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Estado de la lista y del detalle de vehículos (US5).
class VehiclesProvider extends ChangeNotifier {
  VehiclesProvider({required ApiClient api}) : _service = VehiclesService(api);

  final VehiclesService _service;

  LoadStatus _status = LoadStatus.idle;
  List<Vehicle> _items = const <Vehicle>[];
  String? _error;
  String _buscar = '';

  LoadStatus _detailStatus = LoadStatus.idle;
  Vehicle? _selected;
  String? _detailError;

  LoadStatus get status => _status;
  List<Vehicle> get items => _items;
  String? get error => _error;
  String get buscar => _buscar;

  LoadStatus get detailStatus => _detailStatus;
  Vehicle? get selected => _selected;
  String? get detailError => _detailError;

  bool get isLoading => _status == LoadStatus.loading;
  bool get isDetailLoading => _detailStatus == LoadStatus.loading;

  /// Carga la lista; `clienteId` filtra por propietario.
  Future<void> load({String? buscar, int? clienteId}) async {
    if (buscar != null) {
      _buscar = buscar;
    }
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _items = await _service.list(buscar: _buscar, clienteId: clienteId);
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _items = const <Vehicle>[];
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _items = const <Vehicle>[];
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> reload() => load();

  /// Carga la ficha de un vehículo con su propietario.
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

  void clearDetail() {
    _selected = null;
    _detailStatus = LoadStatus.idle;
    _detailError = null;
  }

  /// Registra un vehículo. El propietario es obligatorio (RN-1) y las placas
  /// y el VIN deben ser únicos (FR-023).
  Future<Vehicle> create({
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placas,
    String? vin,
    required int kilometrajeActual,
  }) async {
    final Vehicle created = await _service.create(
      clienteId: clienteId,
      marca: marca,
      modelo: modelo,
      anio: anio,
      placas: placas,
      vin: vin,
      kilometrajeActual: kilometrajeActual,
    );
    await reload();
    return created;
  }

  /// Actualiza un vehículo (por ejemplo, su kilometraje).
  Future<Vehicle> update({
    required int id,
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placas,
    String? vin,
    required int kilometrajeActual,
  }) async {
    final Vehicle updated = await _service.update(
      id: id,
      clienteId: clienteId,
      marca: marca,
      modelo: modelo,
      anio: anio,
      placas: placas,
      vin: vin,
      kilometrajeActual: kilometrajeActual,
    );
    await reload();
    return updated;
  }
}
