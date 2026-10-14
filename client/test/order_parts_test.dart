// Pruebas de las refacciones de la orden en Flutter (US7, Sprint 3): el
// selector del catálogo con su stock visible, la validación local antes de
// enviar, el `409 STOCK_INSUFICIENTE` del backend en el aviso (RN-8) y el
// retiro con confirmación obligatoria que recarga el stock (FR-023 a FR-026).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/app_user.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/models/part.dart';
import 'package:motorix_client/models/service_order.dart';
import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/providers/parts_provider.dart';
import 'package:motorix_client/providers/payment_provider.dart';
import 'package:motorix_client/providers/ticket_provider.dart';
import 'package:motorix_client/providers/service_orders_provider.dart';
import 'package:motorix_client/screens/service_order_detail_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/service_orders_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_parts_service.dart';
import 'fake_payments_service.dart';
import 'fake_tickets_service.dart';

/// Servicio falso con las refacciones de la orden en memoria: cada alta y
/// baja queda registrada y `addFailure` simula el `409` del backend.
class _ServiceOrdersServiceFake extends ServiceOrdersService {
  _ServiceOrdersServiceFake({this.ordenActual, this.addFailure})
      : super(ApiClient());

  ServiceOrder? ordenActual;

  /// Si se define, el alta lanza este error (p. ej. `STOCK_INSUFICIENTE`).
  ApiException? addFailure;

  final List<({int partId, int cantidad})> altas =
      <({int partId, int cantidad})>[];
  final List<int> bajas = <int>[];

  @override
  Future<ServiceOrder> detail(int id) async => ordenActual ?? _orden(id: id);

  @override
  Future<List<MechanicOption>> listMechanics() async =>
      const <MechanicOption>[];

  @override
  Future<void> addPart({
    required int id,
    required int partId,
    required int cantidad,
  }) async {
    if (addFailure != null) {
      throw addFailure!;
    }
    altas.add((partId: partId, cantidad: cantidad));
    final ServiceOrder base = ordenActual ?? _orden(id: id);
    ordenActual = _copiaContenido(
      base,
      repuestos: <OrderPart>[
        ...base.repuestos,
        OrderPart(
          id: 800 + altas.length,
          // R-06: la fila copia el nombre del catálogo al darse de alta.
          descripcion: _nombreRefaccion(partId),
          cantidad: cantidad,
        ),
      ],
    );
  }

  @override
  Future<void> removePart({
    required int id,
    required int repuestoId,
  }) async {
    bajas.add(repuestoId);
    final ServiceOrder base = ordenActual ?? _orden(id: id);
    ordenActual = _copiaContenido(
      base,
      repuestos: base.repuestos.where((OrderPart p) => p.id != repuestoId).toList(),
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
          username: 'prueba',
          email: 'prueba@motorix.local',
          rol: rol,
        );

  final AppUser _user;

  @override
  AppUser? get user => _user;

  @override
  bool get isAuthenticated => true;
}

/// Catálogo de las pruebas: una refacción con stock y otra agotada.
List<Part> _catalogo() => <Part>[
      parteDePrueba(id: 901, codigo: 'BUJ-1', nombre: 'Juego de bujías'),
      parteDePrueba(
        id: 902,
        codigo: 'FIL-1',
        nombre: 'Filtro de aceite',
        stockActual: 0,
      ),
    ];

String _nombreRefaccion(int partId) {
  for (final Part parte in _catalogo()) {
    if (parte.id == partId) {
      return parte.nombre;
    }
  }
  return 'Refacción $partId';
}

ServiceOrder _orden({
  int id = 7,
  String estado = 'RECIBIDO',
  List<Map<String, dynamic>> repuestos = const <Map<String, dynamic>>[],
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
    'fechaIngreso': '2026-10-14',
    'kilometrajeEntrada': 45200,
    'mecanicoId': 3,
    'mecanico': 'mecanico',
    'servicios': <Map<String, dynamic>>[],
    'repuestos': repuestos,
  });
}

ServiceOrder _copiaContenido(
  ServiceOrder base, {
  List<OrderPart>? repuestos,
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
    notaCorreccionKilometraje: base.notaCorreccionKilometraje,
    mecanicoId: base.mecanicoId,
    mecanico: base.mecanico,
    citaId: base.citaId,
    diagnostico: base.diagnostico,
    diagnosticoBorrador: base.diagnosticoBorrador,
    recomendaciones: base.recomendaciones,
    servicios: base.servicios,
    repuestos: repuestos ?? base.repuestos,
    historial: base.historial,
  );
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<
    ({
      _ServiceOrdersServiceFake fake,
      ServiceOrdersProvider provider,
      FakePartsService catalogo,
    })
  >
  pumpDetail(
    WidgetTester tester, {
    String rol = Rol.mechanic,
    ServiceOrder? orden,
    ApiException? addFailure,
  }) async {
    // Altura amplia para que el panel de refacciones quepa sin scroll.
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
      ordenActual: orden ?? _orden(id: 7),
      addFailure: addFailure,
    );
    final ServiceOrdersProvider provider = ServiceOrdersProvider(
      api: ApiClient(),
      service: fake,
    );
    final FakePartsService catalogo = FakePartsService(parts: _catalogo());

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
            create: (_) =>
                PartsProvider(api: ApiClient(), service: catalogo),
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
    return (fake: fake, provider: provider, catalogo: catalogo);
  }

  group('ServiceOrderDetailScreen — refacciones de la orden (US7)', () {
    testWidgets(
      'elige una refacción del catálogo, la envía con su cantidad y limpia el selector',
      (WidgetTester tester) async {
        final ({
          _ServiceOrdersServiceFake fake,
          ServiceOrdersProvider provider,
          FakePartsService catalogo,
        }) estado = await pumpDetail(tester);

        await tester.tap(find.byKey(const Key('selector-refaccion')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Juego de bujías (BUJ-1) · stock 6').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('campo-cantidad')), '2');
        await tester.tap(find.text('Agregar refacción'));
        await tester.pumpAndSettle();

        expect(
          estado.fake.altas,
          <({int partId, int cantidad})>[(partId: 901, cantidad: 2)],
        );
        expect(
          find.text('Refacción registrada en la orden.'),
          findsOneWidget,
        );
        expect(find.text('2 × Juego de bujías'), findsOneWidget);
        // El selector vuelve a su pista para la siguiente alta.
        expect(find.text('Selecciona una refacción'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('campo-cantidad')))
              .controller!
              .text,
          isEmpty,
          reason: 'la cantidad se limpia después de agregar',
        );
      },
    );

    testWidgets(
      'sin elegir una refacción no se envía nada y se pide la selección',
      (WidgetTester tester) async {
        final ({
          _ServiceOrdersServiceFake fake,
          ServiceOrdersProvider provider,
          FakePartsService catalogo,
        }) estado = await pumpDetail(tester);

        await tester.enterText(find.byKey(const Key('campo-cantidad')), '3');
        await tester.tap(find.text('Agregar refacción'));
        await tester.pumpAndSettle();

        expect(estado.fake.altas, isEmpty);
        expect(
          find.text(
            'Selecciona una refacción del catálogo y una cantidad de al menos 1.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'una refacción sin stock no se puede elegir en el selector (RN-8)',
      (WidgetTester tester) async {
        final ({
          _ServiceOrdersServiceFake fake,
          ServiceOrdersProvider provider,
          FakePartsService catalogo,
        }) estado = await pumpDetail(tester);

        await tester.tap(find.byKey(const Key('selector-refaccion')));
        await tester.pumpAndSettle();
        // El stock 0 es visible pero el ítem queda deshabilitado.
        expect(find.text('Filtro de aceite (FIL-1) · stock 0'), findsWidgets);
        await tester.tap(find.text('Filtro de aceite (FIL-1) · stock 0').last);
        await tester.pumpAndSettle();

        expect(
          find.text('Selecciona una refacción'),
          findsOneWidget,
          reason: 'una refacción agotada no debe poder seleccionarse',
        );

        // Un ítem deshabilitado no cierra el menú: se descarta desde su
        // barrera, como haría el usuario al pulsar fuera.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('campo-cantidad')), '1');
        await tester.tap(find.text('Agregar refacción'));
        await tester.pumpAndSettle();

        expect(estado.fake.altas, isEmpty);
        expect(
          find.text(
            'Selecciona una refacción del catálogo y una cantidad de al menos 1.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'el 409 STOCK_INSUFICIENTE del backend se muestra en el aviso (RN-8)',
      (WidgetTester tester) async {
        final ({
          _ServiceOrdersServiceFake fake,
          ServiceOrdersProvider provider,
          FakePartsService catalogo,
        }) estado = await pumpDetail(
          tester,
          addFailure: ApiException(
            'Solo hay 6 unidades disponibles en el inventario',
            codigo: 'STOCK_INSUFICIENTE',
            statusCode: 409,
          ),
        );

        await tester.tap(find.byKey(const Key('selector-refaccion')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Juego de bujías (BUJ-1) · stock 6').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('campo-cantidad')), '9');
        await tester.tap(find.text('Agregar refacción'));
        await tester.pumpAndSettle();

        expect(estado.fake.altas, isEmpty, reason: 'el alta fue rechazada');
        expect(
          find.text('Solo hay 6 unidades disponibles en el inventario'),
          findsOneWidget,
        );
        // El formulario no pierde la refacción elegida tras el rechazo.
        expect(find.text('Juego de bujías (BUJ-1) · stock 6'), findsOneWidget);
      },
    );

    testWidgets(
      'el retiro exige confirmación y recarga el stock del catálogo (FR-026)',
      (WidgetTester tester) async {
        final ({
          _ServiceOrdersServiceFake fake,
          ServiceOrdersProvider provider,
          FakePartsService catalogo,
        }) estado = await pumpDetail(
          tester,
          orden: _orden(
            repuestos: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 44,
                'descripcion': 'Juego de bujías',
                'cantidad': 2,
              },
            ],
          ),
        );
        final int cargasPrevias = estado.catalogo.llamadasList;

        await tester.tap(find.byTooltip('Eliminar refacción'));
        await tester.pumpAndSettle();
        expect(find.text('Eliminar refacción'), findsOneWidget);

        // Cancelar no retira nada (confirmación obligatoria).
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(estado.fake.bajas, isEmpty);
        expect(find.text('2 × Juego de bujías'), findsOneWidget);

        await tester.tap(find.byTooltip('Eliminar refacción'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        expect(estado.fake.bajas, <int>[44]);
        expect(find.text('Refacción retirada de la orden.'), findsOneWidget);
        expect(find.text('Sin refacciones registradas.'), findsOneWidget);
        expect(
          estado.catalogo.llamadasList,
          greaterThan(cargasPrevias),
          reason: 'el stock visible debe refrescarse tras la reposición',
        );
      },
    );

    testWidgets(
      'una orden cerrada no ofrece el formulario de refacciones',
      (WidgetTester tester) async {
        final ({
          _ServiceOrdersServiceFake fake,
          ServiceOrdersProvider provider,
          FakePartsService catalogo,
        }) estado = await pumpDetail(
          tester,
          orden: _orden(
            estado: 'TERMINADO',
            repuestos: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 44,
                'descripcion': 'Juego de bujías',
                'cantidad': 2,
              },
            ],
          ),
        );

        expect(find.byKey(const Key('selector-refaccion')), findsNothing);
        expect(find.text('Agregar refacción'), findsNothing);
        expect(find.byTooltip('Eliminar refacción'), findsNothing);
        // La lista de lo usado en la orden sigue visible.
        expect(find.text('2 × Juego de bujías'), findsOneWidget);
        expect(estado.fake.altas, isEmpty);
      },
    );
  });
}
