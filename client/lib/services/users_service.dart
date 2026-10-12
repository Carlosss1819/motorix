import '../models/user_record.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Datos para crear un usuario desde la interfaz.
class NewUser {
  const NewUser({
    required this.username,
    required this.email,
    required this.rol,
    required this.contrasena,
  });

  final String username;
  final String email;
  final String rol;
  final String contrasena;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'username': username,
        'email': email,
        'rol': rol,
        'contrasena': contrasena,
      };
}

/// Operaciones del recurso `/api/users` (solo ADMIN, el backend valida).
class UsersService {
  UsersService(this._api);

  final ApiClient _api;

  /// GET /api/users
  Future<List<UserRecord>> list() async {
    final dynamic data = await _api.get('/users');
    return asList(data).map(UserRecord.fromJson).toList();
  }

  /// POST /api/users. Devuelve 409 si el usuario o el correo ya existen.
  Future<UserRecord> create(NewUser user) async {
    final dynamic data = await _api.post('/users', body: user.toJson());
    return UserRecord.fromJson(asMap(data));
  }

  /// PATCH /api/users/:id, con efecto inmediato sobre la sesión del usuario.
  Future<UserRecord> update(int id, {String? rol, String? estado}) async {
    final dynamic data = await _api.patch(
      '/users/$id',
      body: <String, dynamic>{
        'rol': ?rol,
        'estado': ?estado,
      },
    );
    return UserRecord.fromJson(asMap(data));
  }
}
