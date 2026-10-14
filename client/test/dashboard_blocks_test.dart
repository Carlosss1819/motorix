// Pruebas de los bloques operativos del panel de control (US6, FR-011,
// Sprint 4): citas, mantenimientos y alertas de inventario con datos reales,
// estados vacíos amigables por bloque (HU6-4) y la acción «Actualizar» que
// refresca todo el resumen (D4).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/dashboard.md.
// Convenciones: viewport 1280×3000 y GoogleFonts sin descargas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/dashboard_summary.dart';
import 'package:motorix_client/providers/dashboard_provider.dart';
import 'package:motorix_client/screens/dashboard_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_dashboard_service.dart';

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Panel con su proveedor y servicio falso.
  Future<void> pumpPanel(
    WidgetTester tester, {
    required FakeDashboardService service,
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) =>
                DashboardProvider(api: ApiClient(), service: service),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('DashboardScreen — bloques operativos (US6, FR-011)', () {
    testWidgets(
      'pinta citas, mantenimientos y alertas con sus datos de prueba',
      (WidgetTester tester) async {
        final FakeDashboardService service = FakeDashboardService(
          resumen: dashboardDePrueba(),
        );
        await pumpPanel(tester, service: service);

        // Encabezados de los cuatro bloques.
        expect(find.text('Órdenes'), findsOneWidget);
        expect(find.text('Citas'), findsOneWidget);
        expect(find.text('Mantenimientos'), findsOneWidget);
        expect(find.text('Inventario'), findsOneWidget);

        // Citas: total de hoy y la próxima con su estado.
        expect(find.byKey(const Key('valor-citas-hoy')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('valor-citas-hoy')),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('cita-9')), findsOneWidget);
        expect(
          find.text('2026-10-15 10:00 · María López'),
          findsOneWidget,
        );
        expect(find.text('Programada'), findsOneWidget);

        // Mantenimientos: vencido y próximo con su objetivo (HU6).
        expect(find.byKey(const Key('mantenimiento-vencido-2')), findsOneWidget);
        expect(find.text('Rotación de llantas'), findsOneWidget);
        expect(
          find.textContaining('Objetivo: 2026-10-01'),
          findsOneWidget,
        );
        expect(find.text('Vencido'), findsOneWidget);
        expect(find.byKey(const Key('mantenimiento-proximo-5')), findsOneWidget);
        expect(find.text('Cambio de aceite'), findsOneWidget);
        expect(
          find.textContaining('Nissan Versa ABC-123-D'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Objetivo: 2026-10-20'),
          findsOneWidget,
        );
        expect(find.text('Próximo'), findsOneWidget);

        // Alertas de inventario: total y la refacción en alerta (SC-008).
        expect(find.byKey(const Key('valor-stock-bajo')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('valor-stock-bajo')),
            matching: find.text('1'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('alerta-2')), findsOneWidget);
        expect(
          find.text('PAD-001 · Juego de pastillas delanteras'),
          findsOneWidget,
        );
        expect(find.text('Stock: 3 / mínimo 5'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('alerta-2')),
            matching: find.text('Stock bajo'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'cada bloque sin datos muestra su estado vacío amigable (HU6-4)',
      (WidgetTester tester) async {
        final FakeDashboardService service = FakeDashboardService(
          resumen: const DashboardSummary(
            fecha: '2026-10-14',
            ordenes: DashboardOrdersBlock(),
            citas: DashboardAppointmentsBlock(),
            mantenimientos: DashboardMaintenancesBlock(),
            alertasInventario: DashboardInventoryBlock(),
          ),
        );
        await pumpPanel(tester, service: service);

        expect(find.byKey(const Key('panel-vacio')), findsOneWidget);
        expect(find.byKey(const Key('citas-vacio')), findsOneWidget);
        expect(find.byKey(const Key('mantenimientos-vacio')), findsOneWidget);
        expect(find.byKey(const Key('alertas-vacio')), findsOneWidget);

        expect(
          find.textContaining('No hay citas para hoy'),
          findsOneWidget,
        );
        expect(
          find.textContaining('No hay mantenimientos próximos ni vencidos'),
          findsOneWidget,
        );
        expect(
          find.textContaining('No hay refacciones con stock bajo'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'un bloque vacío no oculta los datos de los demás bloques',
      (WidgetTester tester) async {
        final FakeDashboardService service = FakeDashboardService(
          resumen: const DashboardSummary(
            fecha: '2026-10-14',
            ordenes: DashboardOrdersBlock(
              total: 12,
              abiertas: 7,
              entregadas: 5,
            ),
            citas: DashboardAppointmentsBlock(
              hoy: 0,
              proximas: <DashboardAppointmentLine>[
                DashboardAppointmentLine(
                  id: 9,
                  fecha: '2026-10-15',
                  hora: '10:00',
                  cliente: 'María López',
                  estado: 'PROGRAMADA',
                ),
              ],
            ),
            // Sin mantenimientos ni alertas: esas secciones quedan vacías.
            mantenimientos: DashboardMaintenancesBlock(),
            alertasInventario: DashboardInventoryBlock(),
          ),
        );
        await pumpPanel(tester, service: service);

        // Órdenes y citas conservan sus datos.
        expect(find.byKey(const Key('valor-total-ordenes')), findsOneWidget);
        expect(find.byKey(const Key('valor-citas-hoy')), findsOneWidget);
        expect(find.byKey(const Key('cita-9')), findsOneWidget);

        // Mantenimientos y alertas muestran su vacío sin errores.
        expect(find.byKey(const Key('mantenimientos-vacio')), findsOneWidget);
        expect(find.byKey(const Key('alertas-vacio')), findsOneWidget);
        expect(find.byKey(const Key('panel-vacio')), findsNothing);
      },
    );

    testWidgets(
      'la acción «Actualizar» refresca todos los bloques (D4)',
      (WidgetTester tester) async {
        final FakeDashboardService service = FakeDashboardService(
          resumen: dashboardDePrueba(),
        );
        await pumpPanel(tester, service: service);
        expect(service.llamadas, 1);
        expect(find.byKey(const Key('cita-9')), findsOneWidget);

        // Con datos nuevos, el botón vuelve a pedir el resumen completo.
        service.resumen = panelVacioPrueba();
        await tester.tap(find.byKey(const Key('boton-actualizar')));
        await tester.pumpAndSettle();

        expect(service.llamadas, 2);
        expect(find.byKey(const Key('panel-vacio')), findsOneWidget);
        expect(find.byKey(const Key('citas-vacio')), findsOneWidget);
        expect(find.byKey(const Key('mantenimientos-vacio')), findsOneWidget);
        expect(find.byKey(const Key('alertas-vacio')), findsOneWidget);
        expect(find.byKey(const Key('cita-9')), findsNothing);
      },
    );
  });
}
