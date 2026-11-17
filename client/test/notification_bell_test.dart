// Pruebas de la campana y el panel de avisos (Sprint 6, US1 a US6; T013,
// T027, T032, T037, T041 y T045; contracts/ui-flutter.md).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/models/app_user.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/models/notification.dart';
import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/providers/notifications_provider.dart';
import 'package:motorix_client/providers/shell_provider.dart';
import 'package:motorix_client/screens/appointments_screen.dart';
import 'package:motorix_client/screens/part_detail_screen.dart';
import 'package:motorix_client/screens/service_order_detail_screen.dart';
import 'package:motorix_client/screens/vehicle_detail_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_routes.dart';
import 'package:motorix_client/utils/app_theme.dart';
import 'package:motorix_client/widgets/app_shell.dart';
import 'package:motorix_client/widgets/notification_bell.dart';
import 'package:provider/provider.dart';

import 'fake_notifications_service.dart';

/// Sesión de prueba con el rol indicado, sin tocar la red.
class _AuthFake extends AuthProvider {
  _AuthFake(this._rol) : super(api: ApiClient());

  final String _rol;

  @override
  bool get isAuthenticated => true;

  @override
  AppUser? get user => AppUser(id: 1, username: 'prueba', email: 'prueba@motorix.local', rol: _rol);
}

/// Describe la ruta abierta con sus argumentos, para comprobar el destino.
String _describir(RouteSettings settings) {
  final Object? args = settings.arguments;
  final String detalle = switch (args) {
    ServiceOrderDetailArgs(:final int orderId) => 'orden=$orderId',
    AppointmentsArgs(:final String? fecha) => 'fecha=$fecha',
    VehicleDetailArgs(:final int vehicleId) => 'vehiculo=$vehicleId',
    PartDetailArgs(:final int refaccionId) => 'refaccion=$refaccionId',
    _ => '',
  };
  return 'ruta ${settings.name} $detalle';
}

Future<FakeNotificationsService> _pumpBell(
  WidgetTester tester, {
  FakeNotificationsService? fake,
}) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final FakeNotificationsService servicio = fake ?? FakeNotificationsService(conteo: 4);

  await tester.pumpWidget(
    ChangeNotifierProvider<NotificationsProvider>(
      create: (_) => NotificationsProvider(api: ApiClient(), service: servicio),
      child: MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => settings.name == '/'
              ? const Scaffold(body: Align(alignment: Alignment.topRight, child: NotificationBell()))
              : Scaffold(body: Text(_describir(settings))),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return servicio;
}

Future<void> _abrirPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('notification-bell')));
  await tester.pumpAndSettle();
}

Finder _textoDeInsignia(String texto) =>
    find.descendant(of: find.byKey(const Key('notification-badge')), matching: find.text(texto));

void main() {
  group('NotificationBell — insignia (US1, FR-017)', () {
    testWidgets('muestra el número de avisos sin leer', (WidgetTester tester) async {
      final FakeNotificationsService fake = await _pumpBell(tester);
      expect(fake.llamadasConteo, 1);
      expect(_textoDeInsignia('4'), findsOneWidget);
    });

    testWidgets('con más de 99 muestra «99+»', (WidgetTester tester) async {
      await _pumpBell(tester, fake: FakeNotificationsService(conteo: 120));
      expect(_textoDeInsignia('99+'), findsOneWidget);
    });

    testWidgets('con 0 no muestra insignia', (WidgetTester tester) async {
      await _pumpBell(tester, fake: FakeNotificationsService(conteo: 0));
      expect(find.byKey(const Key('notification-bell')), findsOneWidget);
      expect(find.byKey(const Key('notification-badge')), findsNothing);
    });

    testWidgets('si el contador falla, la campana queda sin insignia y sin error', (
      WidgetTester tester,
    ) async {
      await _pumpBell(
        tester,
        fake: FakeNotificationsService(conteo: 3, errorConteo: ApiException('Sin conexión')),
      );
      expect(find.byKey(const Key('notification-bell')), findsOneWidget);
      expect(find.byKey(const Key('notification-badge')), findsNothing);
      expect(find.text('Sin conexión'), findsNothing);
    });
  });

  group('Panel de avisos — estados (US1)', () {
    testWidgets('muestra la carga y luego los grupos con su cantidad', (WidgetTester tester) async {
      final FakeNotificationsService fake = FakeNotificationsService(conteo: 4)
        ..bloqueo = Completer<void>();
      await _pumpBell(tester, fake: fake);
      await tester.tap(find.byKey(const Key('notification-bell')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      fake.bloqueo!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Mantenimientos vencidos (1)'), findsOneWidget);
      expect(find.text('Órdenes detenidas (1)'), findsOneWidget);
      expect(find.text('Refacciones con stock bajo (1)'), findsOneWidget);
      expect(find.text('Citas de hoy (2)'), findsOneWidget);
    });

    testWidgets('sin avisos muestra «No tienes avisos pendientes»', (WidgetTester tester) async {
      await _pumpBell(
        tester,
        fake: FakeNotificationsService(
          resumen: const NotificationsSummary(noLeidos: 0, totalAvisos: 0, grupos: <NotificationGroup>[]),
        ),
      );
      await _abrirPanel(tester);
      expect(find.text('No tienes avisos pendientes'), findsOneWidget);
    });

    testWidgets('con error muestra el mensaje y «Reintentar» vuelve a cargar', (WidgetTester tester) async {
      final FakeNotificationsService fake = FakeNotificationsService(
        conteo: 4,
        errorLista: ApiException('No se pudieron cargar los avisos'),
      );
      await _pumpBell(tester, fake: fake);
      await _abrirPanel(tester);
      expect(find.text('No se pudieron cargar los avisos'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      fake.errorLista = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(fake.llamadasLista, 2);
      expect(find.text('Citas de hoy (2)'), findsOneWidget);
    });
  });

  group('Panel de avisos — destinos (US2 a US4, M1)', () {
    Future<void> tocarYVerificar(
      WidgetTester tester,
      String clave,
      String rutaEsperada,
    ) async {
      final FakeNotificationsService fake = await _pumpBell(tester);
      await _abrirPanel(tester);
      await tester.tap(find.byKey(Key('aviso-$clave')));
      await tester.pumpAndSettle();
      expect(find.text(rutaEsperada), findsOneWidget);
      // Tocar el aviso lo marca como leído (M1).
      expect(fake.leidas, <String>[clave]);
    }

    testWidgets('VEHICULO abre el detalle del vehículo', (WidgetTester tester) async {
      await tocarYVerificar(tester, 'MANT_VENCIDO:7:2026-11-01|-', 'ruta ${Routes.vehicleDetail} vehiculo=4');
    });

    testWidgets('CITAS abre Citas con la fecha del aviso', (WidgetTester tester) async {
      await tocarYVerificar(tester, 'CITA_HOY:9:2026-11-16', 'ruta ${Routes.appointments} fecha=2026-11-16');
    });

    testWidgets('REFACCION abre el detalle de la refacción', (WidgetTester tester) async {
      await tocarYVerificar(tester, 'STOCK_BAJO:5', 'ruta ${Routes.partDetail} refaccion=5');
    });

    testWidgets('ORDEN abre el detalle de la orden', (WidgetTester tester) async {
      await tocarYVerificar(
        tester,
        'ORDEN_DETENIDA:12:DIAGNOSTICO',
        'ruta ${Routes.serviceOrderDetail} orden=12',
      );
    });
  });

  group('Panel de avisos — marcar como leído (US6)', () {
    testWidgets('el botón marca el aviso, el contador baja en 1 y el leído no tiene botón', (
      WidgetTester tester,
    ) async {
      final FakeNotificationsService fake = await _pumpBell(tester);
      await _abrirPanel(tester);
      expect(find.byKey(const Key('marcar-leido-CITA_HOY:10:2026-11-16')), findsNothing);

      await tester.tap(find.byKey(const Key('marcar-leido-STOCK_BAJO:5')));
      await tester.pumpAndSettle();
      expect(fake.leidas, <String>['STOCK_BAJO:5']);
      expect(find.byKey(const Key('marcar-leido-STOCK_BAJO:5')), findsNothing);

      // Al cerrar el panel, la insignia muestra 3 (antes 4).
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(_textoDeInsignia('3'), findsOneWidget);
    });

    testWidgets('los avisos leídos se ven atenuados', (WidgetTester tester) async {
      await _pumpBell(tester);
      await _abrirPanel(tester);
      final Opacity leido = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const Key('aviso-CITA_HOY:10:2026-11-16')),
          matching: find.byType(Opacity),
        ).first,
      );
      final Opacity noLeido = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const Key('aviso-CITA_HOY:9:2026-11-16')),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(leido.opacity, lessThan(1));
      expect(noLeido.opacity, 1);
    });
  });

  group('Campana en el AppShell (US5)', () {
    testWidgets('con sesión MECHANIC la campana aparece y el panel solo trae órdenes detenidas', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final FakeNotificationsService fake = FakeNotificationsService(
        conteo: 1,
        resumen: resumenDeMecanico(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: <ChangeNotifierProvider<dynamic>>[
            ChangeNotifierProvider<ShellProvider>(create: (_) => ShellProvider(initialWidth: 1400)),
            ChangeNotifierProvider<AuthProvider>(create: (_) => _AuthFake(Rol.mechanic)),
            ChangeNotifierProvider<NotificationsProvider>(
              create: (_) => NotificationsProvider(api: ApiClient(), service: fake),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AppShell(child: Text('contenido')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('notification-bell')), findsOneWidget);
      expect(_textoDeInsignia('1'), findsOneWidget);
      await _abrirPanel(tester);
      expect(find.text('Órdenes detenidas (1)'), findsOneWidget);
      expect(find.byKey(const Key('grupo-${NotificationTypes.ordenDetenida}')), findsOneWidget);
      expect(find.byKey(const Key('grupo-${NotificationTypes.stockBajo}')), findsNothing);
      expect(find.byKey(const Key('grupo-${NotificationTypes.citaHoy}')), findsNothing);
      expect(find.byKey(const Key('grupo-${NotificationTypes.mantVencido}')), findsNothing);
    });

    // Reporte de Carlos (2026-11-17): en la web no veía la campana. La causa
    // era una compilación web vieja; esta prueba fija que en escritorio/web la
    // campana está en el encabezado, arriba a la derecha, junto al usuario.
    for (final Size pantalla in const <Size>[Size(1920, 1080), Size(1366, 768), Size(1280, 720)]) {
      testWidgets(
        'con sesión ADMIN en pantalla ancha ${pantalla.width.toInt()}x${pantalla.height.toInt()} '
        'la campana está en el encabezado',
        (WidgetTester tester) async {
          tester.view.physicalSize = pantalla;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);
          final FakeNotificationsService fake = FakeNotificationsService(conteo: 4);

          await tester.pumpWidget(
            MultiProvider(
              providers: <ChangeNotifierProvider<dynamic>>[
                ChangeNotifierProvider<ShellProvider>(
                  create: (_) => ShellProvider(initialWidth: pantalla.width),
                ),
                ChangeNotifierProvider<AuthProvider>(create: (_) => _AuthFake(Rol.admin)),
                ChangeNotifierProvider<NotificationsProvider>(
                  create: (_) => NotificationsProvider(api: ApiClient(), service: fake),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                home: const AppShell(child: Text('contenido')),
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          final Finder campana = find.byKey(const Key('notification-bell'));
          expect(campana, findsOneWidget, reason: 'La campana debe verse en pantallas anchas');
          expect(_textoDeInsignia('4'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'El encabezado no debe desbordarse');

          // Está en la franja del encabezado (arriba) y en la mitad derecha.
          final Offset centro = tester.getCenter(campana);
          final Offset usuario = tester.getCenter(find.text('prueba').last);
          expect(centro.dy, lessThan(100), reason: 'La campana debe estar en el encabezado');
          expect(centro.dx, greaterThan(pantalla.width * 0.75), reason: 'La campana va a la derecha');
          expect(centro.dx, lessThan(usuario.dx), reason: 'La campana va antes del usuario');
        },
      );
    }
  });
}
