import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error de la API con un mensaje claro en español, listo para mostrar al
/// usuario. Nunca contiene trazas internas.
class ApiException implements Exception {
  ApiException(this.mensaje, {this.codigo, this.statusCode});

  /// Mensaje en español, apto para la interfaz.
  final String mensaje;

  /// Código de negocio devuelto por el backend (si lo hay).
  final String? codigo;

  /// Código HTTP de la respuesta (si lo hay).
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => mensaje;
}

/// Cliente HTTP de la API REST de Motorix.
///
/// - La base URL sale de la variable de entorno `API_BASE_URL`
///   (por defecto `http://localhost:3000/api`).
/// - El token JWT se guarda solo en memoria.
/// - Las respuestas de error `{error: {mensaje, codigo}}` se convierten en
///   [ApiException] con el mensaje en español.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// URL base de la API, configurable en tiempo de compilación con
  /// `--dart-define=API_BASE_URL=https://servidor/api`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  static const Duration _timeout = Duration(seconds: 20);

  static const String _connectionError =
      'No se pudo conectar con el servidor. Verifica que el servicio esté '
      'disponible e inténtalo de nuevo.';

  final http.Client _client;
  String? _token;

  /// Se ejecuta antes de cada petición. Puede lanzar [ApiException] (por
  /// ejemplo, cuando la sesión expiró por inactividad).
  void Function()? onBeforeRequest;

  /// Se ejecuta cuando el backend responde `401` teniendo una sesión abierta.
  void Function()? onUnauthorized;

  /// Guarda el token de la sesión actual en memoria.
  void setToken(String? token) => _token = token;

  String? get token => _token;

  bool get hasToken => _token != null;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final Uri base = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) {
      return base;
    }
    final Map<String, String> params =
        Map<String, String>.from(base.queryParameters);
    query.forEach((String key, String value) {
      if (value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    });
    return base.replace(queryParameters: params);
  }

  Map<String, String> _headers({required bool includeJsonContentType}) {
    return <String, String>{
      if (includeJsonContentType) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    onBeforeRequest?.call();

    final Uri uri = _buildUri(path, query);
    final String? encodedBody = body == null ? null : jsonEncode(body);
    final Map<String, String> headers =
        _headers(includeJsonContentType: encodedBody != null);

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(_timeout);
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: encodedBody)
              .timeout(_timeout);
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: encodedBody)
              .timeout(_timeout);
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: encodedBody)
              .timeout(_timeout);
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(_timeout);
        default:
          throw ApiException('Método HTTP no soportado: $method');
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(_connectionError);
    }

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final int status = response.statusCode;

    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      data = null;
    }

    if (status >= 200 && status < 300) {
      return data;
    }

    String mensaje = _defaultMessageFor(status);
    String? codigo;
    if (data is Map<String, dynamic>) {
      final Object? error = data['error'];
      if (error is Map<String, dynamic>) {
        if (error['mensaje'] is String) {
          mensaje = error['mensaje'] as String;
        }
        if (error['codigo'] is String) {
          codigo = error['codigo'] as String;
        }
      }
    }

    if (status == 401 && hasToken) {
      onUnauthorized?.call();
    }

    throw ApiException(mensaje, codigo: codigo, statusCode: status);
  }

  static String _defaultMessageFor(int status) {
    return switch (status) {
      400 => 'Revisa los datos ingresados: alguno de ellos no es válido.',
      401 =>
        'Las credenciales no son válidas o tu sesión ha caducado. Inicia sesión de nuevo.',
      403 => 'No tienes permisos para realizar esta operación.',
      404 => 'No se encontró el registro solicitado.',
      409 =>
        'La información entra en conflicto con un registro existente. Revisa los datos duplicados.',
      423 =>
        'La cuenta está bloqueada temporalmente por intentos fallidos. Intenta de nuevo más tarde.',
      >= 500 => 'Ocurrió un error en el servidor. Intenta de nuevo más tarde.',
      _ => 'Ocurrió un error inesperado. Intenta de nuevo.',
    };
  }
}
