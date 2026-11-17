// Pruebas de «Clientes por avisar» (Sprint 6, US7, T049) y de la fecha
// inicial de Citas (destino del aviso «Cita de hoy», T026/T027).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_client/models/appointment.dart';
import 'package:motorix_client/models/client_notice.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/providers/appointments_provider.dart';
import 'package:motorix_client/providers/client_notices_provider.dart';
import 'package:motorix_client/providers/shell_provider.dart';
import 'package:motorix_client/screens/appointments_screen.dart';
import 'package:motorix_client/screens/client_notices_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/appointments_service.dart';
import 'package:motorix_client/utils/app_routes.dart';
import 'package:motorix_client/utils/app_theme.dart';
import 'package:motorix_client/widgets/app_shell.dart';
import 'package:provider/provider.dart';

import 'fake_notifications_service.dart';

Future<FakeClientNoticesService> _pump(
  WidgetTester tester, {
  FakeClientNoticesService? fake,
  double ancho = 1280,
}) async {
  tester.view.physicalSize = Size(ancho, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final FakeClientNoticesService servicio = fake ?? FakeClientNoticesService();
  await tester.pumpWidget(
    ChangeNotifierProvider<ClientNoticesProvider>(
      create: (_) => ClientNoticesProvider(api: ApiClient(), service: servicio),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ClientNoticesScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  return servicio;
}

/// Toca «Marcar como avisado». La fuente de las pruebas hace el texto más
/// ancho que en la app, así que primero se desplaza la tabla hasta el botón.
Future<void> _tocarMarcar(WidgetTester tester, String clave) async {
  final Finder boton = find.byKey(Key('marcar-avisado-$clave'));
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
}

class _AppointmentsServiceFake extends AppointmentsService {
  _AppointmentsServiceFake() : super(ApiClient());

  final List<String> fechas = <String>[];

  @override
  Future<AppointmentPage> list({
    String fecha = '',
    String desde = '',
    String hasta = '',
    String estado = '',
    String buscar = '',
    int pagina = 1,
    int porPagina = 10,
  }) async {
    fechas.add(fecha);
    return const AppointmentPage(elementos: <Appointment>[], pagina: 1, paginas: 1, total: 0);
  }
}

void main() {
  group('ClientNoticesScreen — estados (US7)', () {
    testWidgets('muestra la lista con teléfono y motivo', (WidgetTester tester) async {
      await _pump(tester);
      expect(find.text('Laura Méndez'), findsOneWidget);
      expect(find.text('5550060001'), findsWidgets);
      expect(find.text('Vehículo listo'), findsOneWidget);
      expect(find.text('Cita de mañana'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
    });

    testWidgets('en pantalla angosta muestra la lista en tarjetas', (WidgetTester tester) async {
      await _pump(tester, ancho: 600);
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('Teléfono: 5550060001'), findsWidgets);
    });

    testWidgets('sin pendientes muestra «No hay clientes por avisar»', (WidgetTester tester) async {
      await _pump(tester, fake: FakeClientNoticesService(elementos: <ClientNotice>[]));
      expect(find.text('No hay clientes por avisar'), findsOneWidget);
    });

    testWidgets('con error muestra el mensaje y «Reintentar» vuelve a cargar', (WidgetTester tester) async {
      final FakeClientNoticesService fake = FakeClientNoticesService(
        errorLista: ApiException('No se pudo cargar la lista'),
      );
      await _pump(tester, fake: fake);
      expect(find.text('No se pudo cargar la lista'), findsOneWidget);

      fake.errorLista = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(fake.llamadasLista, 2);
      expect(find.text('Laura Méndez'), findsOneWidget);
    });
  });

  group('ClientNoticesScreen — marcar como avisado (US7, FR-020)', () {
    testWidgets('pide confirmación; al confirmar el renglón sale y aparece «Aviso registrado»', (
      WidgetTester tester,
    ) async {
      final FakeClientNoticesService fake = await _pump(tester);
      await _tocarMarcar(tester, 'ORDEN:60003');
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Ya avisaste a Laura Méndez?'), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(fake.marcadas, <String>['ORDEN:60003']);
      expect(find.text('Laura Méndez'), findsNothing);
      expect(find.text('Pedro Ruiz'), findsOneWidget);
      expect(find.text('Aviso registrado'), findsOneWidget);
    });

    testWidgets('cancelar la confirmación no registra nada', (WidgetTester tester) async {
      final FakeClientNoticesService fake = await _pump(tester);
      await _tocarMarcar(tester, 'ORDEN:60003');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(fake.marcadas, isEmpty);
      expect(find.text('Laura Méndez'), findsOneWidget);
    });

    testWidgets('con 409 muestra el mensaje del servidor y recarga la lista', (WidgetTester tester) async {
      final FakeClientNoticesService fake = FakeClientNoticesService(
        errorMarcar: ApiException(
          'Otra persona ya registró este aviso',
          codigo: 'YA_AVISADO',
          statusCode: 409,
        ),
      );
      await _pump(tester, fake: fake);
      expect(fake.llamadasLista, 1);
      await _tocarMarcar(tester, 'ORDEN:60003');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(find.text('Otra persona ya registró este aviso'), findsOneWidget);
      expect(fake.llamadasLista, 2);
    });
  });

  group('Menú lateral (US7, FR-022)', () {
    test('la sección aparece para ADMIN y RECEPTIONIST y no para MECHANIC', () {
      bool tiene(String rol) => ShellSections.forRole(rol)
          .any((ShellSection s) => s.route == Routes.clientNotices);
      expect(tiene(Rol.admin), isTrue);
      expect(tiene(Rol.receptionist), isTrue);
      expect(tiene(Rol.mechanic), isFalse);
      expect(ShellSections.titleForRoute(Routes.clientNotices), 'Clientes por avisar');
    });
  });

  group('AppointmentsScreen — fecha inicial (destino CITAS)', () {
    testWidgets('abre la lista en el día recibido', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final _AppointmentsServiceFake fake = _AppointmentsServiceFake();
      final AppointmentsProvider citas = AppointmentsProvider(api: ApiClient(), service: fake);

      await tester.pumpWidget(
        MultiProvider(
          providers: <ChangeNotifierProvider<dynamic>>[
            ChangeNotifierProvider<ShellProvider>(create: (_) => ShellProvider(initialWidth: 1280)),
            ChangeNotifierProvider<AppointmentsProvider>.value(value: citas),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: AppointmentsScreen(fechaInicial: '2031-03-04')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(citas.fecha, '2031-03-04');
      expect(fake.fechas.last, '2031-03-04');
      expect(find.widgetWithText(TextField, '2031-03-04'), findsOneWidget);
    });
  });
}
