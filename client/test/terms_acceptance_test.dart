// Pruebas de la aceptación de términos (Sprint 7, US9, FR-017 a FR-019): con
// la aceptación pendiente se muestra la pantalla con la nota de plantilla
// académica; aceptar registra la versión y rechazar cierra la sesión.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/screens/terms_acceptance_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_routes.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'sprint7_test_helpers.dart';

ApiSimulada _api({bool pendiente = true}) => ApiSimulada(<String, Manejador>{
      'POST /api/auth/login': (_) => loginRespuesta(rol: 'RECEPTIONIST', terminosPendientes: pendiente),
      'POST /api/auth/logout': (_) => respuestaJson(<String, dynamic>{'mensaje': 'Sesión cerrada'}),
      'GET /api/terms/current': (_) => respuestaJson(<String, dynamic>{
            'id': 70001, 'version': '1.0', 'publicadoEn': '2026-11-26 00:00:00',
            'terminos': 'TÉRMINOS Y CONDICIONES DE USO', 'avisoPrivacidad': 'AVISO DE PRIVACIDAD INTEGRAL',
            'aceptado': false, 'aceptadoEn': null,
          }),
      'POST /api/terms/accept': (_) => respuestaJson(<String, dynamic>{'version': '1.0', 'aceptadoEn': '2026-11-26 10:00:00'}),
    });

Future<AuthProvider> _sesion(ApiClient cliente) async {
  final AuthProvider auth = AuthProvider(api: cliente);
  await auth.login(identificador: 'recepcion', contrasena: 'Recepcion2026!');
  return auth;
}

Future<void> _montar(WidgetTester tester, AuthProvider auth) async {
  tester.view.physicalSize = const Size(1280, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        theme: AppTheme.light(),
        // Ruta inicial sin «/» para que el regreso a Inicio («/») sea una
        // ruta distinta de la pantalla de términos.
        initialRoute: 'terminos',
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => settings.name == 'terminos'
              ? const TermsAcceptanceScreen()
              : Text('ruta:${settings.name}'),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('test_el_inicio_de_sesion_marca_la_aceptacion_pendiente', () async {
    final AuthProvider auth = await _sesion(_api().cliente);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.termsPending, isTrue);

    final AuthProvider aceptado = await _sesion(_api(pendiente: false).cliente);
    expect(aceptado.termsPending, isFalse);
  });

  testWidgets('test_muestra_los_textos_y_la_nota_de_plantilla_academica', (WidgetTester tester) async {
    final ApiSimulada api = _api();
    await _montar(tester, await _sesion(api.cliente));

    expect(find.text('Términos y condiciones y aviso de privacidad'), findsOneWidget);
    expect(find.byKey(const Key('nota-plantilla-academica')), findsOneWidget);
    expect(find.textContaining('Plantilla académica'), findsOneWidget);
    expect(find.text('TÉRMINOS Y CONDICIONES DE USO'), findsOneWidget);
    expect(find.text('AVISO DE PRIVACIDAD INTEGRAL'), findsOneWidget);
  });

  testWidgets('test_aceptar_registra_la_version_y_entra', (WidgetTester tester) async {
    final ApiSimulada api = _api();
    final AuthProvider auth = await _sesion(api.cliente);
    await _montar(tester, auth);

    await tester.tap(find.byKey(const Key('terminos-aceptar')));
    await tester.pumpAndSettle();

    expect(api.llamadas('POST', '/api/terms/accept').single.cuerpo, <String, dynamic>{'version': '1.0'});
    expect(auth.termsPending, isFalse);
    expect(auth.isAuthenticated, isTrue);
    expect(find.text('ruta:${Routes.home}'), findsOneWidget);
  });

  testWidgets('test_rechazar_cierra_la_sesion_y_vuelve_al_inicio_de_sesion', (WidgetTester tester) async {
    final ApiSimulada api = _api();
    final AuthProvider auth = await _sesion(api.cliente);
    await _montar(tester, auth);

    await tester.tap(find.byKey(const Key('terminos-rechazar')));
    await tester.pumpAndSettle();

    expect(api.llamadas('POST', '/api/auth/logout'), hasLength(1));
    expect(api.llamadas('POST', '/api/terms/accept'), isEmpty);
    expect(auth.isAuthenticated, isFalse);
    expect(find.text('ruta:${Routes.login}'), findsOneWidget);
  });
}
