import '../models/app_user.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Sesión devuelta por el inicio de sesión.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.terminosPendientes = false,
  });

  final String token;
  final AppUser user;

  /// Sprint 7 (US9, FR-017): el usuario debe aceptar la versión vigente de
  /// los términos y el aviso de privacidad antes de usar el sistema.
  final bool terminosPendientes;
}

/// Operaciones de sesión del contrato `contracts/auth.md`.
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  /// POST /api/auth/login con usuario o correo en un mismo campo.
  Future<AuthSession> login({
    required String identificador,
    required String contrasena,
  }) async {
    final dynamic data = await _api.post(
      '/auth/login',
      body: <String, dynamic>{
        'identificador': identificador,
        'contrasena': contrasena,
      },
    );

    if (data is! Map<String, dynamic> ||
        data['token'] is! String ||
        data['usuario'] is! Map<String, dynamic>) {
      throw ApiException('La respuesta del servidor no es válida.');
    }

    return AuthSession(
      token: data['token'] as String,
      user: AppUser.fromJson(asMap(data['usuario'])),
      terminosPendientes: asBool(data['terminosPendientes']),
    );
  }

  /// POST /api/auth/logout. El cliente descarta el token siempre.
  Future<void> logout() async {
    await _api.post('/auth/logout');
  }

  /// GET /api/auth/me: sesión actual.
  Future<AppUser> me() async {
    final dynamic data = await _api.get('/auth/me');
    return AppUser.fromJson(asMap(data));
  }

  /// POST /api/auth/change-password (política: 8 caracteres, mayúscula,
  /// minúscula y número).
  Future<void> changePassword({
    required String actual,
    required String nueva,
  }) async {
    await _api.post(
      '/auth/change-password',
      body: <String, dynamic>{'actual': actual, 'nueva': nueva},
    );
  }
}
