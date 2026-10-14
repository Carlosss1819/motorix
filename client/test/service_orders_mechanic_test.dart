import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/app_user.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/models/service_order.dart';
import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/providers/parts_provider.dart';
import 'package:motorix_client/providers/payment_provider.dart';
import 'package:motorix_client/providers/ticket_provider.dart';
import 'package:motorix_client/providers/service_orders_provider.dart';
import 'package:motorix_client/providers/shell_provider.dart';
import 'package:motorix_client/screens/service_order_detail_screen.dart';
import 'package:motorix_client/screens/service_orders_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/service_orders_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_parts_service.dart';
import 'fake_payments_service.dart';
import 'fake_tickets_service.dart';

/// Servicio falso con datos en memoria: no se abre ninguna conexión.
class _ServiceOrdersServiceFake extends ServiceOrdersService {
  _ServiceOrdersServiceFake({
    this.page,
    this.ordenActual,
    this.mechanics = const <MechanicOption>[],
    this.assignFailure,
  }) : super(ApiClient());

  /// Página que devuelve `list`.
  ServiceOrderPage? page;

  /// Orden que devuelve `detail` y que la asignación va actualizando.
  ServiceOrder? ordenActual;

  /// Mecánicos del selector (`GET /api/users/mechanics`).
  List<MechanicOption> mechanics;

  /// Si se define, `assign` lanza este error (por ejemplo el `409`).
  ApiException? assignFailure;

  int listados = 0;
  final List<int?> asignaciones = <int?>[];

  @override
  Future<ServiceOrderPage> list({
    String buscar = '',
    String estado = '',
    int pagina = 1,
    int porPagina = 10,
  }) async {
    listados += 1;
    return page ??
        const ServiceOrderPage(
          elementos: <ServiceOrder>[],
          pagina: 1,
          paginas: 1,
          total: 0,
        );
  }

  @override
  Future<ServiceOrder> detail(int id) async => ordenActual ?? _orden(id: id);

  @override
  Future<List<MechanicOption>> listMechanics() async => mechanics;

  @override
  Future<AssignedMechanic> assign({
    required int id,
    required int? mecanicoId,
  }) async {
    if (assignFailure != null) {
      throw assignFailure!;
    }
    asignaciones.add(mecanicoId);
    final String? nombre = mecanicoId == null ? null : 'Juan Mecánico';
    ordenActual = _copiaCon(
      ordenActual ?? _orden(id: id),
      mecanicoId: mecanicoId,
      mecanico: nombre,
    );
    return AssignedMechanic(id: id, mecanicoId: mecanicoId, mecanico: nombre);
  }
}

/// Sesión simulada con el rol indicado, sin tocar la red.
class _AuthProviderFake extends AuthProvider {
  _AuthProviderFake({required super.api, required String rol})
      : _user = AppUser(
          id: rol == Rol.mechanic ? 3 : 2,
          username: rol == Rol.mechanic ? 'mecanico' : 'recepcion',
          email: rol == Rol.mechanic
              ? 'mecanico@motorix.local'
              : 'recepcion@motorix.local',
          rol: rol,
        );

  final AppUser _user;

  @override
  AppUser? get user => _user;

  @override
  bool get isAuthenticated => true;
}

ServiceOrder _orden({
  int id = 4,
  String estado = 'RECIBIDO',
  int? mecanicoId,
  String? mecanico,
}) {
  return ServiceOrder.fromJson(<String, dynamic>{
    'id': id,
    'clienteId': 1,
    'cliente': 'Juan Pérez',
    'vehiculoId': 1,
    'vehiculo': 'Nissan Versa 2020',
    'placas': 'ABC1234',
    'estado': estado,
    'motivoVisita': 'Revisión de frenos',
    'fechaIngreso': '2026-10-13',
    'kilometrajeEntrada': 45200,
    'mecanicoId': mecanicoId,
    'mecanico': mecanico,
  });
}

ServiceOrder _copiaCon(
  ServiceOrder base, {
  int? mecanicoId,
  String? mecanico,
}) {
  return ServiceOrder(
    id: base.id,
    clienteId: base.clienteId,
    cliente: base.cliente,
    telefono: base.telefono,
    vehiculoId: base.vehiculoId,
    vehiculo: base.vehiculo,
    placas: base.placas,
    estado: base.estado,
    motivoVisita: base.motivoVisita,
    fechaIngreso: base.fechaIngreso,
    kilometrajeEntrada: base.kilometrajeEntrada,
    mecanicoId: mecanicoId,
    mecanico: mecanico,
  );
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ServiceOrdersProvider — asignación de mecánico (US3)', () {
    test('asignar refresca la ficha y recarga el listado', () async {
      final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
        ordenActual: _orden(id: 7, mecanicoId: 3, mecanico: 'mecanico'),
      );
      final ServiceOrdersProvider provider = ServiceOrdersProvider(
        api: ApiClient(),
        service: fake,
      );
      await provider.loadDetail(7);

      final AssignedMechanic resultado = await provider.assign(
        id: 7,
        mecanicoId: null,
      );

      expect(resultado.mecanicoId, isNull);
      expect(fake.asignaciones, <int?>[null]);
      expect(
        provider.selected?.mecanicoId,
        isNull,
        reason: 'la ficha debe reflejar la desasignación',
      );
      expect(fake.listados, greaterThan(0), reason: 'el listado debe recargarse');
    });

    test('el error del backend (409) llega intacto a la interfaz', () async {
      final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
        ordenActual: _orden(id: 8, estado: 'TERMINADO'),
        assignFailure: ApiException(
          'Una orden terminada o entregada no admite reasignación de mecánico',
          codigo: 'ORDEN_CERRADA',
          statusCode: 409,
        ),
      );
      final ServiceOrdersProvider provider = ServiceOrdersProvider(
        api: ApiClient(),
        service: fake,
      );

      await expectLater(
        provider.assign(id: 8, mecanicoId: 3),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.mensaje,
            'mensaje',
            'Una orden terminada o entregada no admite reasignación de mecánico',
          ),
        ),
      );
      expect(fake.asignaciones, isEmpty, reason: 'no debe enviarse nada');
    });
  });

  group('ServiceOrdersScreen — alcance por rol (US3/FR-010)', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required _ServiceOrdersServiceFake fake,
      required String rol,
    }) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShellProvider>(
              create: (_) => ShellProvider(initialWidth: 1280),
            ),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => _AuthProviderFake(api: ApiClient(), rol: rol),
            ),
            ChangeNotifierProvider<ServiceOrdersProvider>(
              create: (_) =>
                  ServiceOrdersProvider(api: ApiClient(), service: fake),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ServiceOrdersScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'el mecánico ve Mis órdenes sin alta ni filtro global de estado',
      (WidgetTester tester) async {
        final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
          page: ServiceOrderPage(
            elementos: <ServiceOrder>[
              _orden(id: 4, mecanicoId: 3, mecanico: 'mecanico'),
            ],
            pagina: 1,
            paginas: 1,
            total: 1,
          ),
        );

        await pumpScreen(tester, fake: fake, rol: Rol.mechanic);

        expect(find.text('Registrar orden'), findsNothing);
        expect(find.text('Todos los estados'), findsNothing);
        expect(find.text('1 orden'), findsOneWidget);
        expect(find.text('Revisión de frenos'), findsOneWidget);
      },
    );

    testWidgets(
      'el mecánico sin órdenes ve el mensaje propio, sin acción de alta',
      (WidgetTester tester) async {
        await pumpScreen(
          tester,
          fake: _ServiceOrdersServiceFake(),
          rol: Rol.mechanic,
        );

        expect(
          find.text('No tienes órdenes asignadas por el momento.'),
          findsOneWidget,
        );
        expect(find.text('Registrar orden'), findsNothing);
      },
    );

    testWidgets(
      'recepción conserva el alta y el filtro de estado',
      (WidgetTester tester) async {
        await pumpScreen(
          tester,
          fake: _ServiceOrdersServiceFake(),
          rol: Rol.receptionist,
        );

        expect(find.text('Registrar orden'), findsNWidgets(2));
        expect(find.text('Todos los estados'), findsOneWidget);
        expect(
          find.text('Todavía no hay órdenes de servicio. Registra la primera '
              'para empezar.'),
          findsOneWidget,
        );
      },
    );
  });

  group('ServiceOrderDetailScreen — asignación de mecánico (US3/FR-009)', () {
    Future<({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})>
        pumpDetail(
      WidgetTester tester, {
      required String rol,
      ServiceOrder? orden,
      List<MechanicOption> mechanics = const <MechanicOption>[],
    }) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
        ordenActual: orden ?? _orden(id: 7),
        mechanics: mechanics,
      );
      final ServiceOrdersProvider provider = ServiceOrdersProvider(
        api: ApiClient(),
        service: fake,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => _AuthProviderFake(api: ApiClient(), rol: rol),
            ),
            ChangeNotifierProvider<ServiceOrdersProvider>.value(
              value: provider,
            ),
            ChangeNotifierProvider<PartsProvider>(
              create: (_) => PartsProvider(
                api: ApiClient(),
                service: FakePartsService(),
              ),
            ),
            ChangeNotifierProvider<PaymentsProvider>(
              create: (_) => PaymentsProvider(
                api: ApiClient(),
                service: FakePaymentsService(),
              ),
            ),
            ChangeNotifierProvider<TicketProvider>(
              create: (_) => TicketProvider(
                api: ApiClient(),
                service: FakeTicketsService(),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ServiceOrderDetailScreen(orderId: 7)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return (fake: fake, provider: provider);
    }

    testWidgets(
      'recepción asigna desde el selector con confirmación previa',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(
          tester,
          rol: Rol.receptionist,
          mechanics: const <MechanicOption>[
            MechanicOption(id: 3, username: 'mecanico'),
            MechanicOption(id: 9, username: 'mecanico2'),
          ],
        );

        expect(find.text('Asignación de mecánico'), findsOneWidget);
        // El selector mantiene sus ítems en el árbol, por eso se busca el
        // último (el del menú desplegado).
        expect(find.text('Sin asignar'), findsWidgets);

        await tester.tap(find.byType(DropdownButtonFormField<int?>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('mecanico2').last);
        await tester.pumpAndSettle();

        // Confirmación obligatoria antes de asignar (Principio VIII).
        expect(find.text('Asignar mecánico'), findsOneWidget);
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        expect(estado.fake.asignaciones, <int?>[9]);
        expect(find.text('Mecánico asignado correctamente.'), findsOneWidget);
      },
    );

    testWidgets(
      'el mecánico no ve el selector de asignación',
      (WidgetTester tester) async {
        await pumpDetail(
          tester,
          rol: Rol.mechanic,
          orden: _orden(id: 7, mecanicoId: 3, mecanico: 'mecanico'),
        );

        expect(find.text('Asignación de mecánico'), findsNothing);
        expect(find.text('Mecánico'), findsOneWidget, reason: 'la ficha sigue mostrando el dato');
      },
    );

    testWidgets(
      'un 409 del backend se muestra tal cual en el aviso',
      (WidgetTester tester) async {
        final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
          ordenActual: _orden(id: 7),
          mechanics: const <MechanicOption>[
            MechanicOption(id: 3, username: 'mecanico'),
          ],
          assignFailure: ApiException(
            'Una orden terminada o entregada no admite reasignación de mecánico',
            codigo: 'ORDEN_CERRADA',
            statusCode: 409,
          ),
        );

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(
                create: (_) =>
                    _AuthProviderFake(api: ApiClient(), rol: Rol.receptionist),
              ),
              ChangeNotifierProvider<ServiceOrdersProvider>(
                create: (_) =>
                    ServiceOrdersProvider(api: ApiClient(), service: fake),
              ),
              ChangeNotifierProvider<PartsProvider>(
                create: (_) => PartsProvider(
                  api: ApiClient(),
                  service: FakePartsService(),
                ),
              ),
              ChangeNotifierProvider<PaymentsProvider>(
                create: (_) => PaymentsProvider(
                  api: ApiClient(),
                  service: FakePaymentsService(),
                ),
              ),
              ChangeNotifierProvider<TicketProvider>(
                create: (_) => TicketProvider(
                  api: ApiClient(),
                  service: FakeTicketsService(),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: ServiceOrderDetailScreen(orderId: 7)),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byType(DropdownButtonFormField<int?>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('mecanico').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Una orden terminada o entregada no admite reasignación de mecánico',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
