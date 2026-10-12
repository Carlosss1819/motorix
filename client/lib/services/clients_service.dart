import '../models/client.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Resultado de registrar un cliente.
///
/// El backend no bloquea un teléfono repetido: responde con un aviso y pide
/// confirmación antes de reenviar (contracts/clients.md).
class ClientCreateResult {
  const ClientCreateResult.created(Client this.client) : aviso = null;

  const ClientCreateResult.warning(String this.aviso) : client = null;

  /// Cliente creado, solo cuando no hubo aviso.
  final Client? client;

  /// Mensaje del aviso de teléfono repetido.
  final String? aviso;

  /// Indica que hay que preguntar al usuario antes de reenviar.
  bool get needsConfirmation => aviso != null;
}

/// Operaciones del recurso `/api/clients`.
class ClientsService {
  ClientsService(this._api);

  final ApiClient _api;

  /// GET /api/clients?buscar=
  Future<List<Client>> list({String buscar = ''}) async {
    final dynamic data = await _api.get(
      '/clients',
      query: <String, String>{'buscar': buscar},
    );
    return asList(data).map(Client.fromJson).toList();
  }

  /// GET /api/clients/:id, con los vehículos asociados.
  Future<Client> detail(int id) async {
    final dynamic data = await _api.get('/clients/$id');
    return Client.fromJson(asMap(data));
  }

  /// POST /api/clients. Reenvía con `confirmar: true` si el usuario acepta el
  /// aviso de teléfono repetido.
  Future<ClientCreateResult> create({
    required String nombre,
    required String telefono,
    String? email,
    bool confirmar = false,
  }) async {
    final dynamic data = await _api.post(
      '/clients',
      body: <String, dynamic>{
        'nombre': nombre,
        'telefono': telefono,
        if (email != null && email.isNotEmpty) 'email': email,
        if (confirmar) 'confirmar': true,
      },
    );

    final Map<String, dynamic> map = asMap(data);
    final Object? aviso = map['aviso'];
    if (aviso is String && map['confirmarReenvio'] == true) {
      return ClientCreateResult.warning(aviso);
    }

    return ClientCreateResult.created(Client.fromJson(map));
  }

  /// PUT /api/clients/:id. Conserva los vehículos asociados.
  Future<Client> update({
    required int id,
    required String nombre,
    required String telefono,
    String? email,
  }) async {
    final dynamic data = await _api.put(
      '/clients/$id',
      body: <String, dynamic>{
        'nombre': nombre,
        'telefono': telefono,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return Client.fromJson(asMap(data));
  }
}
