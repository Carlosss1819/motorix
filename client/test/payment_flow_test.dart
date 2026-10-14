// Pruebas del cobro de una orden en Flutter (US1, Sprint 4): el formulario
// con el desglose y el total que calcula el backend (FR-015, T062), el
// registro exitoso con su aviso, el `409` «orden ya liquidada» (FR-004) en el
// aviso del formulario y el estado vacío del historial de pagos del bloque de
// cobro (SC-001, escenario 3).
// Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/payments.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/app_user.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/models/order_total.dart';
import 'package:motorix_client/models/payment.dart';
import 'package:motorix_client/models/service_order.dart';
import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/providers/parts_provider.dart';
import 'package:motorix_client/providers/payment_provider.dart';
import 'package:motorix_client/providers/service_orders_provider.dart';
import 'package:motorix_client/screens/payment_form_screen.dart';
import 'package:motorix_client/screens/service_order_detail_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/service_orders_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_parts_service.dart';
import 'fake_payments_service.dart';

/// Total de ejemplo del backend (FR-015): mano de obra de 450 y dos
/// refacciones a 320 = 1,090.
OrderTotal _totalDePrueba() => const OrderTotal(
      ordenId: 7,
      subtotalManoDeObra: 450,
      subtotalRefacciones: 640,
      total: 1090,
      desglose: OrderBreakdown(
        manoDeObra: <LaborBreakdownLine>[
          LaborBreakdownLine(
            id: 9,
            descripcion: 'Cambio de pastillas',
            precio: 450,
          ),
        ],
        refacciones: <PartBreakdownLine>[
          PartBreakdownLine(
            id: 3,
            descripcion: 'Juego de pastillas delanteras',
            cantidad: 2,
            precioUnitario: 320,
            subtotal: 640,
          ),
        ],
      ),
    );

/// Sesión simulada de recepción: el cobro es de recepción y administración
/// (FR-003).
class _AuthProviderFake extends AuthProvider {
  _AuthProviderFake({required super.api, required String rol})
      : _user = AppUser(
          id: rol == Rol.admin ? 1 : 2,
          username: rol == Rol.admin ? 'admin' : 'recepcion',
          email: rol == Rol.admin
              ? 'admin@motorix.local'
              : 'recepcion@motorix.local',
          rol: rol,
        );

  final AppUser _user;

  @override
  AppUser? get user => _user;

  @override
  bool get isAuthenticated => true;
}

/// Servicio de órdenes falso: devuelve la orden y una lista de mecánicos
/// vacía, sin abrir ninguna conexión.
class _OrdenesFake extends ServiceOrdersService {
  _OrdenesFake({required this.ordenActual}) : super(ApiClient());

  final ServiceOrder ordenActual;

  @override
  Future<ServiceOrder> detail(int id) async => ordenActual;

  @override
  Future<List<MechanicOption>> listMechanics() async =>
      const <MechanicOption>[];
}

/// Orden `TERMINADO` lista para cobrar.
ServiceOrder _orden({String estado = 'TERMINADO'}) =>
    ServiceOrder.fromJson(<String, dynamic>{
      'id': 7,
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
      'mecanicoId': 3,
      'mecanico': 'mecanico',
    });

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Prepara el formulario de pago SOBRE una pantalla vacía, como en la app
  /// real: al guardar, el pop descubre la pantalla inferior y el snackbar
  /// queda visible en su Scaffold.
  Future<FakePaymentsService> pumpForm(
    WidgetTester tester, {
    FakePaymentsService? service,
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final FakePaymentsService fake =
        service ?? FakePaymentsService(total: _totalDePrueba());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PaymentsProvider>(
            create: (_) => PaymentsProvider(api: ApiClient(), service: fake),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SizedBox.shrink()),
          routes: <String, WidgetBuilder>{
            '/pago': (_) => const Scaffold(
                  body: PaymentFormScreen(
                    args: PaymentFormArgs(ordenId: 7),
                  ),
                ),
          },
          initialRoute: '/pago',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return fake;
  }

  /// Pantalla de detalle de la orden con el bloque de cobro.
  Future<void> pumpDetalle(
    WidgetTester tester, {
    required FakePaymentsService service,
    String estado = 'TERMINADO',
    String rol = Rol.receptionist,
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _AuthProviderFake(api: ApiClient(), rol: rol),
          ),
          ChangeNotifierProvider<ServiceOrdersProvider>(
            create: (_) => ServiceOrdersProvider(
              api: ApiClient(),
              service: _OrdenesFake(ordenActual: _orden(estado: estado)),
            ),
          ),
          ChangeNotifierProvider<PartsProvider>(
            create: (_) =>
                PartsProvider(api: ApiClient(), service: FakePartsService()),
          ),
          ChangeNotifierProvider<PaymentsProvider>(
            create: (_) =>
                PaymentsProvider(api: ApiClient(), service: service),
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
  }

  group('PaymentFormScreen — desglose y total (US1, FR-015)', () {
    testWidgets(
      'muestra el desglose con precios vigentes y precarga el monto total',
      (WidgetTester tester) async {
        await pumpForm(tester);

        expect(find.text('Cambio de pastillas'), findsOneWidget);
        expect(
          find.text('2 × Juego de pastillas delanteras'),
          findsOneWidget,
        );
        expect(find.text('c/u \$320.00'), findsOneWidget);
        expect(find.text('Subtotal mano de obra'), findsOneWidget);
        expect(find.text('Subtotal refacciones'), findsOneWidget);
        expect(find.text('Total a cobrar'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('total-cobrar'))).data,
          '\$1,090.00',
        );
        expect(
          find.text('1090.00'),
          findsOneWidget,
          reason: 'el monto debe venir precargado con el total del backend',
        );
      },
    );

    testWidgets(
      'sin método no se envía y explica la validación en español (HU2-3)',
      (WidgetTester tester) async {
        final FakePaymentsService fake = await pumpForm(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Registrar pago'));
        await tester.pumpAndSettle();

        expect(find.text('El método de pago es obligatorio.'), findsOneWidget);
        expect(fake.ultimoRegistrado, isNull, reason: 'no debe enviarse nada');
      },
    );

    testWidgets(
      'el registro exitoso guarda el pago y regresa con el aviso (SC-001)',
      (WidgetTester tester) async {
        final FakePaymentsService fake = await pumpForm(tester);

        await tester.tap(find.byKey(const Key('selector-metodo')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Efectivo').last);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Registrar pago'));
        await tester.pumpAndSettle();

        expect(fake.ultimoRegistrado, isNotNull);
        expect(fake.ultimoRegistrado!.ordenId, 7);
        expect(fake.ultimoRegistrado!.monto, 1090);
        expect(fake.ultimoRegistrado!.metodo, 'EFECTIVO');
        expect(fake.ultimoRegistrado!.estado, 'PAGADO');
        expect(find.byType(PaymentFormScreen), findsNothing);
        expect(
          find.text('Pago registrado correctamente.'),
          findsOneWidget,
        );
        // Deja pasar la duración del snackbar para no encolar avisos.
        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'el 409 «orden ya liquidada» del backend se muestra en el aviso',
      (WidgetTester tester) async {
        final FakePaymentsService fake = await pumpForm(
          tester,
          service: FakePaymentsService(
            total: _totalDePrueba(),
            errorRegistro: ApiException(
              'La orden ya tiene un pago aprobado',
              codigo: 'ORDEN_YA_LIQUIDADA',
              statusCode: 409,
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('selector-metodo')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Efectivo').last);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Registrar pago'));
        await tester.pumpAndSettle();

        expect(
          find.text('La orden ya tiene un pago aprobado'),
          findsOneWidget,
        );
        expect(find.byType(PaymentFormScreen), findsOneWidget);
        expect(fake.ultimoRegistrado, isNull);
      },
    );
  });

  group('ServiceOrderDetailScreen — bloque de cobro (US1, SC-001)', () {
    testWidgets(
      'una orden sin pagos muestra el estado vacío junto al total',
      (WidgetTester tester) async {
        await pumpDetalle(
          tester,
          service: FakePaymentsService(total: _totalDePrueba()),
        );

        expect(find.text('Cobro y pago'), findsOneWidget);
        expect(find.text('Sin pagos registrados.'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('total-orden'))).data,
          '\$1,090.00',
          reason: 'el total acompaña al historial de pagos (escenario 3)',
        );
        expect(find.byKey(const Key('boton-registrar-pago')), findsOneWidget);
      },
    );

    testWidgets(
      'el pago aprobado se lista con método y estado y liquidada no cobra',
      (WidgetTester tester) async {
        await pumpDetalle(
          tester,
          service: FakePaymentsService(
            total: _totalDePrueba(),
            pagos: <Payment>[
              pagoDePrueba(id: 11, monto: 1090, metodo: 'TARJETA'),
            ],
          ),
        );

        expect(find.text('\$1,090.00 · Tarjeta'), findsOneWidget);
        expect(find.text('Pagado'), findsOneWidget);
        expect(find.text('Sin pagos registrados.'), findsNothing);
        expect(
          find.byKey(const Key('boton-registrar-pago')),
          findsNothing,
          reason: 'la orden liquidada no admite otro cobro (FR-004)',
        );
        expect(
          find.text('Orden liquidada: ya tiene su pago aprobado.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'el mecánico no ve el bloque de cobro (FR-003, RN-15)',
      (WidgetTester tester) async {
        await pumpDetalle(
          tester,
          service: FakePaymentsService(total: _totalDePrueba()),
          rol: Rol.mechanic,
        );

        expect(find.text('Cobro y pago'), findsNothing);
        expect(find.byKey(const Key('boton-registrar-pago')), findsNothing);
      },
    );
  });
}
