// Prueba del formulario de mantenimiento con el catálogo (Sprint 7, US3,
// FR-011; US2, FR-005): elegir un tipo propone intervalo, fecha y
// kilometraje editables, y la antelación vacía la decide el backend con los
// márgenes del taller.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/vehicle.dart';
import 'package:motorix_client/providers/maintenance_provider.dart';
import 'package:motorix_client/providers/vehicles_provider.dart';
import 'package:motorix_client/screens/maintenance_form_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'sprint7_test_helpers.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('test_elegir_un_tipo_propone_y_permite_corregir_antes_de_guardar', (WidgetTester tester) async {
    final ApiSimulada api = ApiSimulada(<String, Manejador>{
      'GET /api/service-types': (_) => respuestaJson(<String, dynamic>{
            'elementos': <Map<String, dynamic>>[
              <String, dynamic>{'id': 70001, 'nombre': 'Cambio de aceite', 'intervaloDias': 180, 'intervaloKm': 5000, 'activo': true},
            ],
          }),
      'GET /api/vehicles': (_) => respuestaJson(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1, 'clienteId': 1, 'dueno': 'Juan Pérez', 'marca': 'Nissan', 'modelo': 'Versa',
              'anio': 2020, 'placas': 'ABC1234', 'kilometrajeActual': 20000,
            },
          ]),
      'POST /api/maintenance': (PeticionRegistrada p) => respuestaJson(<String, dynamic>{
            'id': 9, 'vehiculoId': 1, 'vehiculo': 'Nissan Versa 2020', 'placas': 'ABC1234',
            'tipoServicio': p.cuerpo!['tipoServicio'], 'fechaObjetivo': p.cuerpo!['fechaObjetivo'],
            'kilometrajeObjetivo': p.cuerpo!['kilometrajeObjetivo'], 'intervaloDias': 180, 'intervaloKm': 5000,
            'antelacionDias': 15, 'antelacionKm': 800, 'estado': 'NORMAL',
          }, 201),
    });
    final ApiClient cliente = api.cliente;
    final VehiclesProvider vehicles = VehiclesProvider(api: cliente);
    await vehicles.load();
    expect(vehicles.items.map((Vehicle v) => v.id), contains(1));

    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: cliente),
          ChangeNotifierProvider<VehiclesProvider>.value(value: vehicles),
          ChangeNotifierProvider<MaintenanceProvider>(create: (_) => MaintenanceProvider(api: cliente)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MaintenanceFormScreen(
              args: const MaintenanceFormArgs(vehiculoId: 1),
              hoy: DateTime(2026, 11, 26),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('mantenimiento-tipo-catalogo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambio de aceite · 180 días · 5,000 km').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Cambio de aceite'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '2027-05-25'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '25000'), findsOneWidget);

    // El usuario corrige el kilometraje propuesto (FR-011).
    await tester.enterText(find.widgetWithText(TextFormField, '25000'), '24000');
    await tester.tap(find.text('Programar'));
    await tester.pumpAndSettle();

    final PeticionRegistrada post = api.llamadas('POST', '/api/maintenance').single;
    expect(post.cuerpo, containsPair('kilometrajeObjetivo', 24000));
    expect(post.cuerpo, containsPair('fechaObjetivo', '2027-05-25'));
    expect(post.cuerpo, containsPair('intervaloDias', 180));
    // FR-005: sin antelación capturada, el backend usa el margen del taller.
    expect(post.cuerpo!.containsKey('antelacionDias'), isFalse);
    expect(post.cuerpo!.containsKey('antelacionKm'), isFalse);
  });
}
