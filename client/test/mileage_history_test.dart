import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:motorix_client/models/vehicle_history.dart';
import 'package:motorix_client/providers/clients_provider.dart';
import 'package:motorix_client/providers/service_orders_provider.dart';
import 'package:motorix_client/providers/vehicle_history_provider.dart';
import 'package:motorix_client/providers/vehicles_provider.dart';
import 'package:motorix_client/screens/service_order_form_screen.dart';
import 'package:motorix_client/screens/vehicle_history_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/vehicle_history_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

/// Servicio falso del historial (sin red) para la primera prueba.
class _VehicleHistoryServiceFake extends VehicleHistoryService {
  _VehicleHistoryServiceFake(this.page) : super(ApiClient());

  final HistoryPage page;

  @override
  Future<HistoryPage> list({
    required int vehicleId,
    int pagina = 1,
    int porPagina = 10,
  }) async => page;
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Historial muestra el kilometraje de cada servicio (US2, FR-005)', () {
    testWidgets(
      'cada entrada presenta el kilometraje registrado en su orden',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final HistoryPage page = HistoryPage(
          elementos: <HistoryEntry>[
            HistoryEntry(
              ordenId: 1,
              fechaServicio: '2026-10-10',
              kilometraje: 31000,
              estadoOrden: 'TERMINADO',
              observaciones: null,
              diagnostico: null,
              recomendaciones: null,
              servicios: const <String>['Cambio de aceite'],
              refacciones: const <HistoryPart>[],
            ),
            HistoryEntry(
              ordenId: 2,
              fechaServicio: '2026-09-10',
              kilometraje: 32500,
              estadoOrden: 'ENTREGADO',
              observaciones: null,
              diagnostico: null,
              recomendaciones: null,
              servicios: const <String>['Rotación de llantas'],
              refacciones: const <HistoryPart>[],
            ),
          ],
          pagina: 1,
          paginas: 1,
          total: 2,
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<VehicleHistoryProvider>(
            create: (_) => VehicleHistoryProvider(
              api: ApiClient(),
              service: _VehicleHistoryServiceFake(page),
            ),
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(
                body: VehicleHistoryScreen(
                  args: VehicleHistoryArgs(vehicleId: 1),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('31,000 km'), findsOneWidget);
        expect(find.text('32,500 km'), findsOneWidget);
      },
    );
  });

  group('Formulario de orden responde la regresión de kilometraje (US2, FR-006)', () {
    /// API simulada: clientes y vehículos de ejemplo, y el alta rechazada con
    /// el mensaje real del backend (KILOMETRAJE_MENOR).
    MockClient crearApi() {
      return MockClient((http.Request request) async {
        final String path = request.url.path;
        if (request.method == 'GET' && path == '/api/clients') {
          return http.Response(
            jsonEncode(<Map<String, dynamic>>[
              <String, dynamic>{'id': 1, 'nombre': 'Juan Pérez', 'telefono': '77000000'},
            ]),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
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
                'kilometrajeActual': 45200,
              },
            ]),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST' && path == '/api/service-orders') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'error': <String, dynamic>{
                'mensaje':
                    'El kilometraje de entrada no puede ser menor al de la '
                        'última orden del vehículo (45,200 km)',
                'codigo': 'KILOMETRAJE_MENOR',
              },
            }),
            400,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('Ruta no prevista en la prueba: $path', 500);
      });
    }

    testWidgets(
      'el 400 KILOMETRAJE_MENOR del backend se muestra en el formulario, en español',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final ApiClient api = ApiClient(client: crearApi());

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ClientsProvider>(
                create: (_) => ClientsProvider(api: api),
              ),
              ChangeNotifierProvider<VehiclesProvider>(
                create: (_) => VehiclesProvider(api: api),
              ),
              ChangeNotifierProvider<ServiceOrdersProvider>(
                create: (_) => ServiceOrdersProvider(api: api),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: ServiceOrderFormScreen()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Seleccionar el cliente.
        await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Juan Pérez').last);
        await tester.pumpAndSettle();

        // Seleccionar el vehículo.
        await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nissan Versa 2020 · ABC1234').last);
        await tester.pumpAndSettle();

        // Motivo y kilometraje menor al de la última orden.
        await tester.enterText(
          find.byType(TextField).at(0),
          'Ruido al frenar',
        );
        await tester.enterText(
          find.byType(TextField).at(2),
          '44000',
        );

        // El botón de guardar comparte etiqueta con el título: es el último.
        await tester.tap(find.text('Registrar orden').last);
        await tester.pump();
        await tester.pump();

        expect(
          find.text(
            'El kilometraje de entrada no puede ser menor al de la última '
            'orden del vehículo (45,200 km)',
          ),
          findsOneWidget,
          reason: 'el mensaje en español del backend debe mostrarse al usuario',
        );
      },
    );
  });
}
