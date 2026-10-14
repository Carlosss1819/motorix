// Pruebas del panel de control (US5, FR-010/FR-011, Sprint 4): el resumen de
// órdenes se pinta con datos de prueba, sin órdenes se muestra el estado
// vacío amigable, los errores de carga ofrecen reintentar y la sección «Panel»
// solo se ofrece al administrador (HU5-2, RN-15).
// Fuente de verdad: contracts/dashboard.md.
// Convenciones: viewport 1280×3000 y GoogleFonts sin descargas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/providers/dashboard_provider.dart';
import 'package:motorix_client/screens/dashboard_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_routes.dart';
import 'package:motorix_client/utils/app_theme.dart';
import 'package:motorix_client/widgets/app_shell.dart';

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

  /// Valor mostrado por la fila con la llave indicada.
  Finder valorDe(String llave) => find.descendant(
        of: find.byKey(Key(llave)),
        matching: find.textContaining(RegExp(r'^\d+$')),
      );

  group('DashboardScreen — resumen de órdenes (US5, FR-011)', () {
    testWidgets(
      'pinta los totales y el desglose por estado con datos reales',
      (WidgetTester tester) async {
        final FakeDashboardService service = FakeDashboardService(
          resumen: dashboardDePrueba(),
        );
        await pumpPanel(tester, service: service);

        expect(find.text('Panel de control'), findsOneWidget);
        expect(find.byKey(const Key('boton-actualizar')), findsOneWidget);
        expect(
          find.byKey(const Key('fecha-referencia')),
          findsOneWidget,
        );
        expect(find.text('Resumen del taller al 2026-10-14'), findsOneWidget);

        // Totales del bloque de órdenes.
        expect(valorDe('valor-total-ordenes'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('valor-total-ordenes')),
            matching: find.text('12'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('valor-abiertas-ordenes')),
            matching: find.text('7'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('valor-entregadas-ordenes')),
            matching: find.text('5'),
          ),
          findsOneWidget,
        );

        // Seis filas por estado, con su valor (SC-005: sin dobles conteos).
        expect(find.byKey(const Key('valor-estado-RECIBIDO')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('valor-estado-RECIBIDO')),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('valor-estado-DIAGNOSTICO')), findsOneWidget);
        expect(find.byKey(const Key('valor-estado-EN_REPARACION')), findsOneWidget);
        expect(
          find.byKey(const Key('valor-estado-ESPERANDO_REFACCION')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('valor-estado-TERMINADO')), findsOneWidget);
        expect(find.byKey(const Key('valor-estado-ENTREGADO')), findsOneWidget);
        expect(find.text('Por estado'), findsOneWidget);

        // Una sola petición al abrir (D4).
        expect(service.llamadas, 1);
      },
    );

    testWidgets(
      'sin órdenes muestra un estado vacío amigable (HU6-4)',
      (WidgetTester tester) async {
        final FakeDashboardService service = FakeDashboardService(
          resumen: panelVacioPrueba(),
        );
        await pumpPanel(tester, service: service);

        expect(find.byKey(const Key('panel-vacio')), findsOneWidget);
        expect(
          find.textContaining('Todavía no hay órdenes registradas'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('valor-total-ordenes')), findsNothing);
      },
    );

    testWidgets(
      'un error de carga se muestra con la opción de reintentar',
      (WidgetTester tester) async {
        final FakeDashboardService service = FakeDashboardService(
          error: ApiException(
            'El panel de control es exclusivo del administrador',
            codigo: 'PANEL_SOLO_ADMIN',
            statusCode: 403,
          ),
        );
        await pumpPanel(tester, service: service);

        expect(
          find.textContaining('exclusivo del administrador'),
          findsOneWidget,
        );
        expect(find.widgetWithText(OutlinedButton, 'Reintentar'), findsOneWidget);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
        await tester.pumpAndSettle();

        // El reintento volvió a pedir el resumen.
        expect(service.llamadas, 2);
        expect(
          find.textContaining('exclusivo del administrador'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'la acción «Actualizar» vuelve a pedir el resumen (D4)',
      (WidgetTester tester) async {
        final FakeDashboardService service = FakeDashboardService(
          resumen: dashboardDePrueba(),
        );
        await pumpPanel(tester, service: service);
        expect(service.llamadas, 1);

        await tester.tap(find.byKey(const Key('boton-actualizar')));
        await tester.pumpAndSettle();

        expect(service.llamadas, 2);
        expect(find.text('Resumen del taller al 2026-10-14'), findsOneWidget);
      },
    );
  });

  group('ShellSections — la sección «Panel» es solo de ADMIN (HU5-2, RN-15)',
      () {
    test('el administrador la ve en la navegación', () {
      final List<String> rutas = ShellSections.forRole(Rol.admin)
          .map((ShellSection section) => section.route)
          .toList();

      expect(rutas, contains(Routes.dashboard));
    });

    test('recepción y mecánico no la ven', () {
      final List<String> recepcion = ShellSections.forRole(Rol.receptionist)
          .map((ShellSection section) => section.route)
          .toList();
      final List<String> mecanico = ShellSections.forRole(Rol.mechanic)
          .map((ShellSection section) => section.route)
          .toList();

      expect(recepcion, isNot(contains(Routes.dashboard)));
      expect(mecanico, isNot(contains(Routes.dashboard)));
    });
  });
}
