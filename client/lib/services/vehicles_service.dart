import '../models/vehicle.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones del recurso `/api/vehicles`.
class VehiclesService {
  VehiclesService(this._api);

  final ApiClient _api;

  /// GET /api/vehicles?buscar=&clienteId=
  Future<List<Vehicle>> list({String buscar = '', int? clienteId}) async {
    final dynamic data = await _api.get(
      '/vehicles',
      query: <String, String>{
        'buscar': buscar,
        if (clienteId != null) 'clienteId': '$clienteId',
      },
    );
    return asList(data).map(Vehicle.fromJson).toList();
  }

  /// GET /api/vehicles/:id, con el propietario.
  Future<Vehicle> detail(int id) async {
    final dynamic data = await _api.get('/vehicles/$id');
    return Vehicle.fromJson(asMap(data));
  }

  /// POST /api/vehicles. El propietario es obligatorio (RN-1) y las placas y
  /// el VIN deben ser únicos.
  Future<Vehicle> create({
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placas,
    String? vin,
    required int kilometrajeActual,
  }) async {
    final dynamic data = await _api.post(
      '/vehicles',
      body: _payload(
        clienteId: clienteId,
        marca: marca,
        modelo: modelo,
        anio: anio,
        placas: placas,
        vin: vin,
        kilometrajeActual: kilometrajeActual,
      ),
    );
    return Vehicle.fromJson(asMap(data));
  }

  /// PUT /api/vehicles/:id. En este sprint no se cambia el propietario.
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
    final dynamic data = await _api.put(
      '/vehicles/$id',
      body: _payload(
        clienteId: clienteId,
        marca: marca,
        modelo: modelo,
        anio: anio,
        placas: placas,
        vin: vin,
        kilometrajeActual: kilometrajeActual,
      ),
    );
    return Vehicle.fromJson(asMap(data));
  }

  Map<String, dynamic> _payload({
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placas,
    String? vin,
    required int kilometrajeActual,
  }) {
    return <String, dynamic>{
      'clienteId': clienteId,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'placas': placas,
      if (vin != null && vin.isNotEmpty) 'vin': vin,
      'kilometrajeActual': kilometrajeActual,
    };
  }
}
