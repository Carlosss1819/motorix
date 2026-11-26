import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/terms_service.dart';
import '../utils/messages.dart';

/// Estados posibles de la sesión.
enum AuthStatus { initial, loading, authenticated, unauthenticated }

/// Estado de la sesión actual (FR-001 a FR-004, FR-008).
///
/// El token JWT se guarda solo en memoria y la sesión se cierra a los
/// 30 minutos de inactividad.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required ApiClient api,
    AuthService? service,
    TermsService? termsService,
  })  : _api = api,
        _service = service ?? AuthService(api),
        _termsService = termsService ?? TermsService(api) {
    _api.onBeforeRequest = _handleBeforeRequest;
    _api.onUnauthorized = _handleUnauthorized;
  }

  /// Tiempo máximo de inactividad antes de cerrar la sesión.
  static const Duration inactivityTimeout = Duration(minutes: 30);

  final ApiClient _api;
  final AuthService _service;
  final TermsService _termsService;

  /// Sprint 7 (US9): aceptación de términos pendiente en esta sesión.
  bool _termsPending = false;

  AuthStatus _status = AuthStatus.unauthenticated;
  AppUser? _user;
  String? _token;
  DateTime? _lastActivity;
  String? _error;
  String? _sessionMessage;
  bool _loggingOut = false;

  /// Se invoca cuando la sesión se cierra fuera del control del usuario
  /// (expiración por inactividad o `401` del backend).
  void Function(String message)? onSessionClosed;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get token => _token;

  /// Último mensaje de error del inicio de sesión.
  String? get error => _error;

  /// Motivo por el que la sesión se cerró sin que el usuario lo pidiera.
  String? get sessionMessage => _sessionMessage;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Sprint 7 (US9, FR-017): mientras sea `true`, la app solo muestra la
  /// pantalla de aceptación (el backend responde 403 TERMINOS_PENDIENTES).
  bool get termsPending => _termsPending;

  /// Servicio de términos, compartido con las pantallas de términos.
  TermsService get termsService => _termsService;
  bool get isLoading => _status == AuthStatus.loading;

  /// Limpia el mensaje de error mostrado en el formulario de acceso.
  void clearError() {
    if (_error == null && _sessionMessage == null) {
      return;
    }
    _error = null;
    _sessionMessage = null;
    notifyListeners();
  }

  /// Inicia sesión con usuario o correo en un mismo campo (FR-001, FR-002).
  Future<bool> login({
    required String identificador,
    required String contrasena,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    _sessionMessage = null;
    notifyListeners();

    try {
      final AuthSession session = await _service.login(
        identificador: identificador.trim(),
        contrasena: contrasena,
      );
      _token = session.token;
      _api.setToken(session.token);
      _user = session.user;
      _termsPending = session.terminosPendientes;
      _lastActivity = DateTime.now();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _clearSession();
      _error = e.mensaje;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (_) {
      _clearSession();
      _error = AppMessages.unexpectedError;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Cierra la sesión desde el usuario (con confirmación previa en la
  /// interfaz). El token local se descarta aunque falle el aviso al servidor.
  Future<void> logout() async {
    _loggingOut = true;
    try {
      if (isAuthenticated) {
        await _service.logout();
      }
    } catch (_) {
      // El token local se descarta de todos modos.
    } finally {
      _loggingOut = false;
    }

    _clearSession();
    _status = AuthStatus.unauthenticated;
    _sessionMessage = null;
    notifyListeners();
  }

  /// Acepta la versión vigente de los términos (Sprint 7, FR-018). Lanza
  /// [ApiException] si la versión ya no es la vigente.
  Future<void> acceptTerms(String version) async {
    await _termsService.accept(version);
    _termsPending = false;
    notifyListeners();
  }

  /// Rechazar los términos cierra la sesión (FR-019).
  Future<void> rejectTerms() => logout();

  /// Cambia la contraseña de la cuenta propia (FR-008). Lanza [ApiException]
  /// con el mensaje del backend si la política no se cumple.
  Future<void> changePassword({
    required String actual,
    required String nueva,
  }) {
    return _service.changePassword(actual: actual, nueva: nueva);
  }

  /// Registra actividad y cierra la sesión si ya pasaron los 30 minutos de
  /// inactividad (FR-004).
  void touch() {
    if (!isAuthenticated) {
      return;
    }
    final DateTime? last = _lastActivity;
    if (last != null && DateTime.now().difference(last) >= inactivityTimeout) {
      _closeSession(AppMessages.sessionExpired);
      return;
    }
    _lastActivity = DateTime.now();
  }

  void _handleBeforeRequest() {
    if (!isAuthenticated) {
      return;
    }
    touch();
    if (!isAuthenticated) {
      throw ApiException(AppMessages.sessionExpired);
    }
  }

  void _handleUnauthorized() {
    if (_loggingOut || !isAuthenticated) {
      return;
    }
    _closeSession(AppMessages.sessionClosed);
  }

  void _closeSession(String message) {
    if (!isAuthenticated) {
      return;
    }
    _clearSession();
    _status = AuthStatus.unauthenticated;
    _sessionMessage = message;
    notifyListeners();
    onSessionClosed?.call(message);
  }

  void _clearSession() {
    _token = null;
    _api.setToken(null);
    _user = null;
    _lastActivity = null;
    _termsPending = false;
  }
}
