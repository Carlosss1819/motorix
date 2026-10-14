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
import 'package:motorix_client/providers/service_orders_provider.dart';
import 'package:motorix_client/screens/service_order_detail_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/service_orders_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_parts_service.dart';
import 'fake_payments_service.dart';

/// Servicio falso de solo estado (US5): registra cada transición pedida y
/// puede fallar con un error del backend (403/409).
class _ServiceOrdersServiceFake extends ServiceOrdersService {
  _ServiceOrdersServiceFake({this.ordenActual, this.changeFailure})
      : super(ApiClient());

  ServiceOrder? ordenActual;

  /// Si se define, `changeStatus` lanza este error (por ejemplo el `403`
  /// de un rol no autorizado o el `409` de una transición inválida).
  ApiException? changeFailure;

  final List<String> cambios = <String>[];

  @override
  Future<ServiceOrderPage> list({
    String buscar = '',
    String estado = '',
    int pagina = 1,
    int porPagina = 10,
  }) async =>
      ServiceOrderPage(
        elementos: <ServiceOrder>[?ordenActual],
        pagina: 1,
        paginas: 1,
        total: ordenActual == null ? 0 : 1,
      );

  @override
  Future<ServiceOrder> detail(int id) async => ordenActual ?? _orden(id: id);

  @override
  Future<List<MechanicOption>> listMechanics() async =>
      const <MechanicOption>[];

  @override
  Future<void> changeStatus({
    required int id,
    required String estado,
    String? nota,
  }) async {
    if (changeFailure != null) {
      throw changeFailure!;
    }
    cambios.add(estado);
    final ServiceOrder base = ordenActual ?? _orden(id: id);
    ordenActual = ServiceOrder(
      id: base.id,
      clienteId: base.clienteId,
      cliente: base.cliente,
      telefono: base.telefono,
      vehiculoId: base.vehiculoId,
      vehiculo: base.vehiculo,
      placas: base.placas,
      estado: estado,
      motivoVisita: base.motivoVisita,
      fechaIngreso: base.fechaIngreso,
      kilometrajeEntrada: base.kilometrajeEntrada,
      notaCorreccionKilometraje: base.notaCorreccionKilometraje,
      mecanicoId: base.mecanicoId,
      mecanico: base.mecanico,
      citaId: base.citaId,
      diagnostico: base.diagnostico,
      diagnosticoBorrador: base.diagnosticoBorrador,
      recomendaciones: base.recomendaciones,
      fechaEntrega:
          estado == 'ENTREGADO' ? '2026-10-16T15:00:00.000Z' : base.fechaEntrega,
      servicios: base.servicios,
      repuestos: base.repuestos,
      historial: <OrderHistoryEntry>[
        ...base.historial,
        OrderHistoryEntry(
          de: base.estado,
          a: estado,
          usuario: 'sesion',
          fecha: '2026-10-16T15:00:00.000Z',
        ),
      ],
    );
  }
}

/// Sesión simulada con el rol indicado, sin tocar la red.
class _AuthProviderFake extends AuthProvider {
  _AuthProviderFake({required super.api, required String rol})
      : _user = AppUser(
          id: switch (rol) {
            Rol.mechanic => 3,
            Rol.admin => 1,
            _ => 2,
          },
          username: switch (rol) {
            Rol.mechanic => 'mecanico',
            Rol.admin => 'admin',
            _ => 'recepcion',
          },
          email: switch (rol) {
            Rol.mechanic => 'mecanico@motorix.local',
            Rol.admin => 'admin@motorix.local',
            _ => 'recepcion@motorix.local',
          },
          rol: rol,
        );

  final AppUser _user;

  @override
  AppUser? get user => _user;

  @override
  bool get isAuthenticated => true;
}

ServiceOrder _orden({
  int id = 7,
  String estado = 'RECIBIDO',
  int? mecanicoId = 3,
  String? mecanico = 'mecanico',
  List<Map<String, dynamic>> historial = const <Map<String, dynamic>>[],
}) {
  return ServiceOrder.fromJson(<String, dynamic>{
    'id': id,
    'clienteId': 1,
    'cliente': 'Juan Pérez',
    'telefono': '7221234567',
    'vehiculoId': 1,
    'vehiculo': 'Nissan Versa 2020',
    'placas': 'ABC1234',
    'estado': estado,
    'motivoVisita': 'Revisión de frenos',
    'fechaIngreso': '2026-10-13',
    'kilometrajeEntrada': 45200,
    'mecanicoId': mecanicoId,
    'mecanico': mecanico,
    'historial': historial,
  });
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})>
      pumpDetail(
    WidgetTester tester, {
    required String rol,
    ServiceOrder? orden,
    ApiException? changeFailure,
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
      ordenActual: orden ?? _orden(id: 7),
      changeFailure: changeFailure,
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

  group('ServiceOrderDetailScreen — acciones de estado (US5/FR-022)', () {
    testWidgets(
      'el mecánico asignado ve el bloque medio y nunca la entrega',
      (WidgetTester tester) async {
        await pumpDetail(
          tester,
          rol: Rol.mechanic,
          orden: _orden(estado: 'EN_REPARACION', mecanicoId: 3),
        );

        expect(find.text('Pasar a Esperando refacción'), findsOneWidget);
        expect(find.text('Pasar a Terminado'), findsOneWidget);
        expect(find.text('Pasar a Entregado'), findsNothing);
      },
    );

    testWidgets(
      'un mecánico sin asignación no ve acciones de estado',
      (WidgetTester tester) async {
        await pumpDetail(
          tester,
          rol: Rol.mechanic,
          orden: _orden(estado: 'RECIBIDO', mecanicoId: null, mecanico: null),
        );

        expect(find.text('Acciones de estado'), findsNothing);
        expect(find.textContaining('Pasar a'), findsNothing);
      },
    );

    testWidgets(
      'recepción no gestiona el bloque medio (R-03)',
      (WidgetTester tester) async {
        await pumpDetail(tester, rol: Rol.receptionist);

        expect(find.text('Acciones de estado'), findsNothing);
        expect(find.textContaining('Pasar a'), findsNothing);
      },
    );

    testWidgets(
      'recepción entrega la orden terminada con confirmación previa',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(
          tester,
          rol: Rol.receptionist,
          orden: _orden(estado: 'TERMINADO'),
        );

        expect(find.text('Pasar a Entregado'), findsOneWidget);

        await tester.tap(find.text('Pasar a Entregado'));
        await tester.pumpAndSettle();

        // Confirmación obligatoria para entregar (Principio VIII).
        expect(find.text('Entregar orden'), findsOneWidget);
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        expect(estado.fake.cambios, <String>['ENTREGADO']);
        expect(
          find.text('La orden ahora está en Entregado.'),
          findsOneWidget,
        );
        expect(find.text('Fecha de entrega'), findsOneWidget);
      },
    );

    testWidgets(
      'el mecánico asignado cierra la orden con confirmación',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(
          tester,
          rol: Rol.mechanic,
          orden: _orden(estado: 'DIAGNOSTICO', mecanicoId: 3),
        );

        await tester.tap(find.text('Pasar a Terminado'));
        await tester.pumpAndSettle();

        expect(find.text('Cerrar orden'), findsOneWidget);
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        expect(estado.fake.cambios, <String>['TERMINADO']);
        expect(find.text('La orden ahora está en Terminado.'), findsOneWidget);
      },
    );

    testWidgets(
      'el 403 del backend se muestra tal cual en el aviso',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(
          tester,
          rol: Rol.mechanic,
          orden: _orden(estado: 'RECIBIDO', mecanicoId: 3),
          changeFailure: ApiException(
            'Solo el mecánico asignado a la orden puede cambiar su estado',
            codigo: 'ORDEN_AJENA',
            statusCode: 403,
          ),
        );

        await tester.tap(find.text('Pasar a Diagnóstico'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Solo el mecánico asignado a la orden puede cambiar su estado',
          ),
          findsOneWidget,
        );
        expect(estado.fake.cambios, isEmpty, reason: 'no debe guardarse nada');
      },
    );

    testWidgets(
      'la orden entregada es terminal y no ofrece acciones',
      (WidgetTester tester) async {
        await pumpDetail(
          tester,
          rol: Rol.receptionist,
          orden: _orden(estado: 'ENTREGADO'),
        );

        expect(find.text('Acciones de estado'), findsNothing);
        expect(find.textContaining('Pasar a'), findsNothing);
      },
    );

    testWidgets(
      'el administrador entrega una orden terminada',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(
          tester,
          rol: Rol.admin,
          orden: _orden(estado: 'TERMINADO'),
        );

        await tester.tap(find.text('Pasar a Entregado'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        expect(estado.fake.cambios, <String>['ENTREGADO']);
      },
    );
  });

  group('ServiceOrderDetailScreen — historial de cambios (US5/FR-015)', () {
    testWidgets(
      'muestra cada transición con el usuario y la fecha',
      (WidgetTester tester) async {
        await pumpDetail(
          tester,
          rol: Rol.receptionist,
          orden: _orden(
            estado: 'DIAGNOSTICO',
            historial: <Map<String, dynamic>>[
              <String, dynamic>{
                'de': null,
                'a': 'RECIBIDO',
                'usuario': 'recepcion',
                'fecha': '2026-10-16T14:05:00.000Z',
              },
              <String, dynamic>{
                'de': 'RECIBIDO',
                'a': 'DIAGNOSTICO',
                'usuario': 'mecanico',
                'fecha': '2026-10-16T14:30:00.000Z',
              },
            ],
          ),
        );

        expect(find.text('Historial de cambios'), findsOneWidget);
        expect(find.text('Alta de la orden → Recibido'), findsOneWidget);
        expect(find.text('Recibido → Diagnóstico'), findsOneWidget);
        expect(find.textContaining('recepcion · '), findsOneWidget);
        expect(find.textContaining('mecanico · '), findsOneWidget);
      },
    );

    testWidgets(
      'muestra el mensaje vacío cuando aún no hay transiciones',
      (WidgetTester tester) async {
        await pumpDetail(tester, rol: Rol.receptionist);

        expect(find.text('Historial de cambios'), findsOneWidget);
        expect(find.text('Sin cambios registrados.'), findsOneWidget);
      },
    );
  });
}
