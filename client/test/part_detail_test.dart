import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/part.dart';
import 'package:motorix_client/models/part_movement.dart';
import 'package:motorix_client/providers/part_detail_provider.dart';
import 'package:motorix_client/screens/part_detail_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/parts_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

/// Refacción de prueba con stock ya movido por su historial.
Part _refaccionDePrueba() => const Part(
      id: 7,
      codigo: 'PAS-DEL01',
      nombre: 'Juego de pastillas delanteras',
      categoria: 'Frenos',
      marca: 'Brembo',
      stockActual: 3,
      stockMinimo: 2,
      stockBajo: false,
      precioCompra: 180,
      precioVenta: 320,
      activa: true,
    );

/// Servicio falso con datos en memoria: no se abre ninguna conexión.
class _PartsServiceFake extends PartsService {
  _PartsServiceFake({this.page, this.failure}) : super(ApiClient());

  /// Página que devuelve `movements`.
  PartMovementPage? page;

  /// Si se define, `detail` lanza este error.
  ApiException? failure;

  final List<int> refaccionesConsultadas = <int>[];

  @override
  Future<Part> detail(int id) async {
    refaccionesConsultadas.add(id);
    if (failure != null) {
      throw failure!;
    }
    return _refaccionDePrueba();
  }

  @override
  Future<PartMovementPage> movements({
    required int partId,
    String tipo = '',
    int pagina = 1,
    int porPagina = 10,
  }) async {
    if (failure != null) {
      throw failure!;
    }
    return page ??
        const PartMovementPage(
          elementos: <PartMovement>[],
          pagina: 1,
          paginas: 1,
          total: 0,
        );
  }
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required _PartsServiceFake fake,
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<PartDetailProvider>(
        create: (_) => PartDetailProvider(api: ApiClient(), service: fake),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: PartDetailScreen(
              args: PartDetailArgs(refaccionId: 7),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('PartDetailScreen — detalle y movimientos (US6)', () {
    testWidgets(
      'muestra los datos de la refacción consultada (FR-018)',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake();

        await pumpScreen(tester, fake: fake);

        expect(
          find.text('Juego de pastillas delanteras'),
          findsOneWidget,
          reason: 'el encabezado debe mostrar el nombre de la refacción',
        );
        expect(find.text('PAS-DEL01'), findsOneWidget);
        expect(find.text('Frenos'), findsOneWidget);
        expect(find.text('Brembo'), findsOneWidget);
        expect(find.text('3 unidades'), findsOneWidget);
        expect(find.text('2 unidades'), findsOneWidget);
        expect(find.text('\$180.00'), findsOneWidget);
        expect(find.text('\$320.00'), findsOneWidget);
        expect(find.text('Activo'), findsOneWidget);
        expect(fake.refaccionesConsultadas, <int>[7]);
      },
    );

    testWidgets(
      'lista los movimientos con tipo, cantidad, motivo, orden, stock y fecha '
      '(FR-030, SC-007)',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake(
          page: const PartMovementPage(
            elementos: <PartMovement>[
              PartMovement(
                id: 9,
                tipo: 'SALIDA',
                cantidad: 2,
                motivo: 'Uso en órdenes del taller',
                ordenId: 4,
                stockAfter: 3,
                registradoPor: 'mecanico',
                fecha: '2026-10-13 09:15:00',
              ),
              PartMovement(
                id: 8,
                tipo: 'ENTRADA',
                cantidad: 5,
                motivo: null,
                ordenId: null,
                stockAfter: 5,
                registradoPor: 'admin',
                fecha: '2026-10-10 08:00:00',
              ),
            ],
            pagina: 1,
            paginas: 1,
            total: 2,
          ),
        );

        await pumpScreen(tester, fake: fake);

        expect(find.text('2 movimientos'), findsOneWidget);
        expect(find.text('Salida'), findsOneWidget);
        expect(find.text('-2'), findsOneWidget);
        expect(
          find.text('Uso en órdenes del taller'),
          findsOneWidget,
          reason: 'la salida debe explicar su motivo',
        );
        expect(find.text('#4'), findsOneWidget);
        expect(
          find.text('3'),
          findsOneWidget,
          reason: 'la fila conserva el stock resultante de ese movimiento',
        );
        expect(
          find.text('13/10/2026 09:15'),
          findsOneWidget,
          reason: 'la fecha se muestra con día, mes, año y hora',
        );
        expect(find.text('Entrada'), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);
        expect(
          find.text('Sin motivo'),
          findsOneWidget,
          reason: 'la entrada de stock inicial puede venir sin motivo',
        );
        expect(
          find.text('Sin orden'),
          findsOneWidget,
          reason: 'los movimientos de catálogo no traen orden asociada',
        );
        expect(find.text('10/10/2026 08:00'), findsOneWidget);
      },
    );

    testWidgets(
      'una refacción sin movimientos muestra el aviso de historial vacío',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake();

        await pumpScreen(tester, fake: fake);

        expect(
          find.textContaining('todavía no tiene movimientos'),
          findsOneWidget,
        );
        expect(find.text('0 movimientos'), findsNothing);
      },
    );

    testWidgets(
      'el error del backend se muestra con opción de reintentar',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake(
          failure: ApiException(
            'La refacción no existe',
            codigo: 'REFACCION_NO_ENCONTRADA',
            statusCode: 404,
          ),
        );

        await pumpScreen(tester, fake: fake);

        expect(find.text('La refacción no existe'), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
      },
    );
  });
}
