import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:motorix_client/models/maintenance.dart';
import 'package:motorix_client/providers/maintenance_provider.dart';
import 'package:motorix_client/providers/vehicles_provider.dart';
import 'package:motorix_client/screens/maintenance_form_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_theme.dart';

/// Mantenimiento de ejemplo en modo edición.
Maintenance _mantenimiento() {
  return Maintenance.fromJson(<String, dynamic>{
    'id': 7,
    'vehiculoId': 1,
    'vehiculo': 'Nissan Versa 2020',
    'placas': 'ABC1234',
    'cliente': 'Juan Pérez',
    'tipoServicio': 'Cambio de aceite',
    'fechaUltimoServicio': null,
    'kilometrajeUltimoServicio': null,
    'fechaObjetivo': '2026-12-31',
    'kilometrajeObjetivo': 45000,
    'intervaloDias': 90,
    'intervaloKm': 5000,
    'antelacionDias': 30,
    'antelacionKm': 500,
    'notas': null,
    'estado': 'PROXIMO',
  });
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// API simulada: lista de vehículos, alta aceptada y renovación aceptada;
  /// registra las peticiones POST para asserts.
  MockClient crearApi({required List<String> posts}) {
    return MockClient((http.Request request) async {
      final String path = request.url.path;
      if (request.method == 'GET' && path == '/api/vehicles') {
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'clienteId': 1,
              'dueno': 'Juan Pérez',
              'marca': 'Nissan',
              'modelo': 'Versa',
              'anio': 2020,
              'placas': 'ABC1234',
              'kilometrajeActual': 20000,
            },
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' && path == '/api/maintenance') {
        posts.add(path);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'id': 9,
            'vehiculoId': 1,
            'vehiculo': 'Nissan Versa 2020',
            'placas': 'ABC1234',
            'cliente': 'Juan Pérez',
            'tipoServicio': 'Cambio de aceite y filtro',
            'fechaUltimoServicio': null,
            'kilometrajeUltimoServicio': null,
            'fechaObjetivo': '2026-12-31',
            'kilometrajeObjetivo': 45000,
            'intervaloDias': null,
            'intervaloKm': 5000,
            'antelacionDias': 30,
            'antelacionKm': 500,
            'notas': null,
            'estado': 'NORMAL',
          }),
          201,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' && path == '/api/maintenance/7/realizar') {
        posts.add(path);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'id': 7,
            'vehiculoId': 1,
            'vehiculo': 'Nissan Versa 2020',
            'placas': 'ABC1234',
            'cliente': 'Juan Pérez',
            'tipoServicio': 'Cambio de aceite',
            'fechaUltimoServicio': '2026-10-13',
            'kilometrajeUltimoServicio': 20000,
            'fechaObjetivo': '2027-01-11',
            'kilometrajeObjetivo': 25000,
            'intervaloDias': 90,
            'intervaloKm': 5000,
            'antelacionDias': 30,
            'antelacionKm': 500,
            'notas': null,
            'estado': 'NORMAL',
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }
      return http.Response('Ruta no prevista en la prueba: $path', 500);
    });
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    required ApiClient api,
    MaintenanceFormArgs args = const MaintenanceFormArgs(),
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MaintenanceProvider>(
            create: (_) => MaintenanceProvider(api: api),
          ),
          ChangeNotifierProvider<VehiclesProvider>(
            create: (_) => VehiclesProvider(api: api),
          ),
        ],
        // Como en la app real, el formulario se empuja SOBRE la pantalla que
        // lo abre: al guardar, el pop descubre la pantalla inferior y el
        // snackbar queda visible en su Scaffold.
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SizedBox.shrink()),
          routes: <String, WidgetBuilder>{
            '/form': (_) => Scaffold(body: MaintenanceFormScreen(args: args)),
          },
          initialRoute: '/form',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('MaintenanceFormScreen — alta (US3/HU3)', () {
    testWidgets(
      'programar un mantenimiento con objetivo y vehículo',
      (WidgetTester tester) async {
        final List<String> posts = <String>[];
        await pumpForm(tester, api: ApiClient(client: crearApi(posts: posts)));

        // Seleccionar el vehículo.
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nissan Versa 2020 · ABC1234').last);
        await tester.pumpAndSettle();

        // Tipo de servicio y objetivos.
        await tester.enterText(find.byType(TextField).at(0), 'Cambio de aceite y filtro');
        await tester.enterText(find.byType(TextField).at(1), '2026-12-31');
        await tester.enterText(find.byType(TextField).at(2), '45000');
        await tester.enterText(find.byType(TextField).at(4), '5000');

        await tester.tap(find.text('Programar').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(posts, <String>['/api/maintenance']);
        expect(
          find.text('Mantenimiento programado correctamente.'),
          findsOneWidget,
        );
        // Deja pasar la duración del snackbar para no encolar avisos.
        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'sin objetivo de fecha ni kilometraje no se envía y se explica en español',
      (WidgetTester tester) async {
        final List<String> posts = <String>[];
        await pumpForm(
          tester,
          api: ApiClient(client: crearApi(posts: posts)),
          args: const MaintenanceFormArgs(vehiculoId: 1),
        );

        await tester.enterText(find.byType(TextField).at(0), 'Rotación de llantas');
        await tester.tap(find.text('Programar').last);
        await tester.pump();

        expect(
          find.text('Indica la fecha o el kilometraje del próximo servicio.'),
          findsOneWidget,
        );
        expect(posts, isEmpty, reason: 'no debe enviarse nada al backend');
      },
    );
  });

  group('MaintenanceFormScreen — servicio realizado (US3, FR-015)', () {
    testWidgets(
      'exige confirmación: cancelar no renueva y confirmar sí',
      (WidgetTester tester) async {
        final List<String> posts = <String>[];
        await pumpForm(
          tester,
          api: ApiClient(client: crearApi(posts: posts)),
          args: MaintenanceFormArgs(mantenimiento: _mantenimiento()),
        );

        // Abrir la confirmación y cancelar.
        await tester.tap(find.text('Marcar servicio realizado').last);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('¿Continuar?'),
          findsOneWidget,
          reason: 'la confirmación debe explicar qué hará el backend',
        );
        // «Cancelar» también existe en el formulario: el del diálogo es el único
        // descendiente de Dialog.
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Cancelar'),
          ),
        );
        await tester.pumpAndSettle();
        expect(posts, isEmpty, reason: 'cancelar no debe renovar nada');

        // Confirmar: se renueva el mismo registro.
        await tester.tap(find.text('Marcar servicio realizado').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Marcar realizado'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(posts, <String>['/api/maintenance/7/realizar']);
        expect(
          find.text('Servicio realizado. El mantenimiento se renovó.'),
          findsOneWidget,
        );
        // El objetivo del formulario se refresca con la renovación.
        expect(find.widgetWithText(TextFormField, '25000'), findsOneWidget);
        // Deja pasar la duración del snackbar para no encolar avisos.
        await tester.pump(const Duration(seconds: 4));
      },
    );
  });
}
