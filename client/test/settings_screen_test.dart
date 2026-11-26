// Pruebas de la pantalla de Configuración (Sprint 7, US1/US2): carga los
// datos del taller y los márgenes, valida los límites y guarda con PUT.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:motorix_client/screens/settings_screen.dart';

import 'sprint7_test_helpers.dart';

Map<String, dynamic> _config({String nombre = 'Motorix'}) => <String, dynamic>{
      'taller': <String, dynamic>{'nombre': nombre, 'direccion': 'Av. Ejemplo 123', 'telefono': '55-0000-0000'},
      'mantenimiento': <String, dynamic>{'antelacionDias': 30, 'antelacionKm': 500},
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  ApiSimulada crearApi() => ApiSimulada(<String, Manejador>{
        'GET /api/settings': (_) => respuestaJson(_config()),
        'PUT /api/settings': (PeticionRegistrada p) =>
            respuestaJson(_config(nombre: p.cuerpo!['nombreTaller'] as String)),
      });

  testWidgets('test_carga_los_datos_del_taller_y_los_margenes', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: const SettingsScreen(), api: api.cliente);

    expect(find.text('Configuración del taller'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Motorix'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '30'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '500'), findsOneWidget);
  });

  testWidgets('test_valida_los_limites_antes_de_guardar', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: const SettingsScreen(), api: api.cliente);

    await tester.enterText(find.byKey(const Key('config-nombre')), '');
    await tester.enterText(find.byKey(const Key('config-dias')), '400');
    await tester.tap(find.byKey(const Key('config-guardar')));
    await tester.pump();

    expect(find.text('Ingresa el nombre del taller.'), findsOneWidget);
    expect(find.textContaining('entre 1 y 365'), findsOneWidget);
    expect(api.llamadas('PUT', '/api/settings'), isEmpty);
  });

  testWidgets('test_guarda_la_configuracion_y_muestra_el_aviso', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: const SettingsScreen(), api: api.cliente);

    await tester.enterText(find.byKey(const Key('config-nombre')), 'Taller Centro');
    await tester.enterText(find.byKey(const Key('config-km')), '800');
    await tester.tap(find.byKey(const Key('config-guardar')));
    await tester.pump();
    await tester.pump();

    final PeticionRegistrada put = api.llamadas('PUT', '/api/settings').single;
    expect(put.cuerpo, <String, dynamic>{
      'nombreTaller': 'Taller Centro',
      'direccionTaller': 'Av. Ejemplo 123',
      'telefonoTaller': '55-0000-0000',
      'antelacionDias': 30,
      'antelacionKm': 800,
    });
    expect(find.textContaining('Configuración guardada'), findsOneWidget);
  });
}
