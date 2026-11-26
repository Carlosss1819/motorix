// Apoyo de las pruebas del Sprint 7: API simulada con respuestas por método y
// ruta, registro de las peticiones y montaje de pantallas con el tema real.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_theme.dart';

/// Petición registrada por la API simulada.
class PeticionRegistrada {
  PeticionRegistrada(this.metodo, this.ruta, this.query, this.cuerpo);

  final String metodo;
  final String ruta;
  final Map<String, String> query;
  final Map<String, dynamic>? cuerpo;
}

/// Manejador de una ruta de la API simulada.
typedef Manejador = http.Response Function(PeticionRegistrada peticion);

/// Respuesta JSON de la API simulada.
http.Response respuestaJson(Object? cuerpo, [int status = 200]) => http.Response(
      jsonEncode(cuerpo),
      status,
      headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
    );

/// API simulada: `rutas` asocia «MÉTODO /api/ruta» con su respuesta.
class ApiSimulada {
  ApiSimulada(this.rutas);

  final Map<String, Manejador> rutas;
  final List<PeticionRegistrada> peticiones = <PeticionRegistrada>[];

  late final ApiClient cliente = ApiClient(
    client: MockClient((http.Request request) async {
      final PeticionRegistrada peticion = PeticionRegistrada(
        request.method,
        request.url.path,
        request.url.queryParameters,
        request.body.isEmpty ? null : jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>,
      );
      peticiones.add(peticion);
      final Manejador? handler =
          rutas['${request.method} ${request.url.path}'];
      if (handler == null) {
        return respuestaJson(<String, dynamic>{
          'error': <String, dynamic>{'mensaje': 'Recurso no encontrado', 'codigo': 'NO_ENCONTRADO'},
        }, 404);
      }
      return handler(peticion);
    }),
  );

  Iterable<PeticionRegistrada> llamadas(String metodo, String ruta) =>
      peticiones.where((PeticionRegistrada p) => p.metodo == metodo && p.ruta == ruta);
}

/// Monta [child] con el tema real, el cliente HTTP y una sesión opcional.
Future<void> montarPantalla(
  WidgetTester tester, {
  required Widget child,
  required ApiClient api,
  AuthProvider? auth,
}) async {
  tester.view.physicalSize = const Size(1280, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
      ],
      child: auth == null
          ? MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child))
          : ChangeNotifierProvider<AuthProvider>.value(
              value: auth,
              child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
            ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Respuesta del inicio de sesión con la aceptación indicada.
http.Response loginRespuesta({String rol = 'ADMIN', bool terminosPendientes = false}) =>
    respuestaJson(<String, dynamic>{
      'token': 'token-de-prueba',
      'usuario': <String, dynamic>{'id': 1, 'username': 'prueba', 'email': 'prueba@motorix.local', 'rol': rol},
      'terminosPendientes': terminosPendientes,
    });
