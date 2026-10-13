import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/vehicle_history.dart';
import 'package:motorix_client/providers/vehicle_history_provider.dart';
import 'package:motorix_client/screens/vehicle_history_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/vehicle_history_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

/// Servicio falso con datos en memoria: no se abre ninguna conexión.
class _VehicleHistoryServiceFake extends VehicleHistoryService {
  _VehicleHistoryServiceFake({this.page, this.failure})
      : super(ApiClient());

  /// Página que devuelve `list`.
  HistoryPage? page;

  /// Si se define, `list` lanza este error.
  ApiException? failure;

  int listados = 0;
  final List<int> vehiculosConsultados = <int>[];

  @override
  Future<HistoryPage> list({
    required int vehicleId,
    int pagina = 1,
    int porPagina = 10,
  }) async {
    listados += 1;
    vehiculosConsultados.add(vehicleId);
    if (failure != null) {
      throw failure!;
    }
    return page ??
        const HistoryPage(
          elementos: <HistoryEntry>[],
          pagina: 1,
          paginas: 1,
          total: 0,
        );
  }
}

/// Entrada de ejemplo con el detalle completo del servicio (FR-002).
HistoryEntry _entrada({int ordenId = 10}) {
  return HistoryEntry.fromJson(<String, dynamic>{
    'ordenId': ordenId,
    'fechaServicio': '2026-10-10',
    'kilometraje': 45200,
    'estadoOrden': 'TERMINADO',
    'observaciones': 'Ruido al frenar',
    'diagnostico': 'Pastillas delanteras desgastadas',
    'recomendaciones': 'Revisar discos en el próximo servicio',
    'servicios': <String>['Cambio de pastillas delanteras'],
    'refacciones': <Map<String, dynamic>>[
      <String, dynamic>{
        'partId': 3,
        'codigo': 'PAS-DEL01',
        'nombre': 'Juego de pastillas delanteras',
        'cantidad': 1,
      },
    ],
  });
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required _VehicleHistoryServiceFake fake,
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<VehicleHistoryProvider>(
        create: (_) => VehicleHistoryProvider(api: ApiClient(), service: fake),
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
  }

  group('VehicleHistoryScreen — historial del vehículo (US1)', () {
    testWidgets(
      'un vehículo sin servicios terminados muestra el historial vacío (SC-003)',
      (WidgetTester tester) async {
        await pumpScreen(tester, fake: _VehicleHistoryServiceFake());

        expect(
          find.textContaining('todavía no tiene servicios terminados'),
          findsOneWidget,
        );
        expect(find.text('1 servicio'), findsNothing);
      },
    );

    testWidgets(
      'cada entrada muestra fecha, kilometraje, estado y el detalle del servicio',
      (WidgetTester tester) async {
        final _VehicleHistoryServiceFake fake = _VehicleHistoryServiceFake(
          page: const HistoryPage(
            elementos: <HistoryEntry>[
              HistoryEntry(
                ordenId: 10,
                fechaServicio: '2026-10-10',
                kilometraje: 45200,
                estadoOrden: 'TERMINADO',
                observaciones: 'Ruido al frenar',
                diagnostico: 'Pastillas delanteras desgastadas',
                recomendaciones: 'Revisar discos en el próximo servicio',
                servicios: <String>['Cambio de pastillas delanteras'],
                refacciones: <HistoryPart>[
                  HistoryPart(
                    partId: 3,
                    codigo: 'PAS-DEL01',
                    nombre: 'Juego de pastillas delanteras',
                    cantidad: 1,
                  ),
                ],
              ),
            ],
            pagina: 1,
            paginas: 1,
            total: 1,
          ),
        );

        await pumpScreen(tester, fake: fake);

        expect(find.text('10/10/2026'), findsOneWidget);
        expect(find.text('45,200 km'), findsOneWidget);
        expect(find.text('Ruido al frenar'), findsOneWidget);
        expect(
          find.text('Pastillas delanteras desgastadas'),
          findsOneWidget,
        );
        expect(
          find.text('Cambio de pastillas delanteras'),
          findsOneWidget,
        );
        expect(
          find.text('PAS-DEL01 · Juego de pastillas delanteras (x1)'),
          findsOneWidget,
          reason: 'la refacción debe mostrar código, nombre y cantidad',
        );
        expect(
          find.text('Revisar discos en el próximo servicio'),
          findsOneWidget,
        );
        expect(fake.vehiculosConsultados, <int>[1]);
      },
    );

    testWidgets(
      'las refacciones heredadas sin código muestran solo el nombre (R-06)',
      (WidgetTester tester) async {
        final _VehicleHistoryServiceFake fake = _VehicleHistoryServiceFake(
          page: const HistoryPage(
            elementos: <HistoryEntry>[
              HistoryEntry(
                ordenId: 11,
                fechaServicio: '2026-09-01',
                kilometraje: 44000,
                estadoOrden: 'ENTREGADO',
                observaciones: null,
                diagnostico: null,
                recomendaciones: null,
                servicios: <String>[],
                refacciones: <HistoryPart>[
                  HistoryPart(
                    partId: null,
                    codigo: null,
                    nombre: 'Refacción registrada antes del inventario',
                    cantidad: 2,
                  ),
                ],
              ),
            ],
            pagina: 1,
            paginas: 1,
            total: 1,
          ),
        );

        await pumpScreen(tester, fake: fake);

        expect(
          find.text('Refacción registrada antes del inventario (x2)'),
          findsOneWidget,
        );
        expect(find.textContaining('·'), findsNothing);
      },
    );

    testWidgets(
      'el error del backend se muestra con opción de reintentar',
      (WidgetTester tester) async {
        final _VehicleHistoryServiceFake fake = _VehicleHistoryServiceFake(
          failure: ApiException(
            'El vehículo no existe',
            codigo: 'VEHICULO_NO_ENCONTRADO',
            statusCode: 404,
          ),
        );

        await pumpScreen(tester, fake: fake);

        expect(find.text('El vehículo no existe'), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
      },
    );
  });
}
