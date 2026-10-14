// Pruebas del flujo Mercado Pago en Flutter (US3, Sprint 4): el cobro nace
// PENDIENTE con su referencia externa, enlace y modo de pasarela simulado
// (FR-005, D1, RN-14) y el bloque de la orden ofrece las acciones de
// confirmación manual que lo aprueban, rechazan o cancelan (aclaración 3).
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
import 'package:motorix_client/providers/ticket_provider.dart';
import 'package:motorix_client/providers/service_orders_provider.dart';
import 'package:motorix_client/screens/payment_form_screen.dart';
import 'package:motorix_client/screens/service_order_detail_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/service_orders_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_parts_service.dart';
import 'fake_payments_service.dart';
import 'fake_tickets_service.dart';

/// Total de ejemplo no nulo para que el monto venga precargado (FR-015).
const OrderTotal _totalPrueba = OrderTotal(
  ordenId: 7,
  subtotalManoDeObra: 450,
  subtotalRefacciones: 0,
  total: 450,
);

/// Sesión simulada de recepción (el cobro es de recepción y administración).
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

/// Servicio de órdenes falso: devuelve la orden y sin mecánicos, sin red.
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

  /// Formulario de pago sobre una pantalla vacía, como en la app real: al
  /// volver, el pop descubre la pantalla inferior.
  Future<FakePaymentsService> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final FakePaymentsService fake = FakePaymentsService(total: _totalPrueba);

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
  }

  group('PaymentFormScreen — cobro Mercado Pago (US3, FR-005)', () {
    testWidgets(
      'queda PENDIENTE con referencia, enlace y modo simulado (D1, RN-14)',
      (WidgetTester tester) async {
        final FakePaymentsService fake = await pumpForm(tester);

        await tester.tap(find.byKey(const Key('selector-metodo')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mercado Pago').last);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Registrar pago'));
        await tester.pumpAndSettle();

        expect(fake.ultimoRegistrado, isNotNull);
        expect(fake.ultimoRegistrado!.estado, 'PENDIENTE');
        expect(fake.ultimoRegistrado!.modoPasarela, 'simulado');

        // La pantalla no se cierra: muestra el resultado del cobro (US3).
        expect(find.byType(PaymentFormScreen), findsOneWidget);
        expect(find.text('Cobro Mercado Pago iniciado'), findsOneWidget);
        expect(find.text('Pendiente'), findsOneWidget);
        expect(find.text('Referencia externa'), findsOneWidget);
        expect(
          find.textContaining('SIM-MOT-7-'),
          findsOneWidget,
          reason: 'debe mostrarse la referencia externa guardada',
        );
        expect(find.text('Modo de pasarela'), findsOneWidget);
        expect(
          find.text('simulado (sin credenciales)'),
          findsOneWidget,
          reason: 'sin MP_ACCESS_TOKEN el modo es simulado (D1)',
        );
        expect(find.text('Enlace de pago'), findsOneWidget);
        expect(
          find.textContaining('sandbox.mercadopago.com.mx'),
          findsOneWidget,
        );
        // RN-14: nada que parezca un dato de tarjeta o una credencial.
        expect(
          find.textContaining('4111'),
          findsNothing,
          reason: 'la app nunca muestra números de tarjeta',
        );

        await tester.tap(find.byKey(const Key('boton-volver-orden')));
        await tester.pumpAndSettle();

        expect(find.byType(PaymentFormScreen), findsNothing);
      },
    );
  });

  group('ServiceOrderDetailScreen — confirmación del cobro (US3, FR-005)', () {
    testWidgets(
      'un pendiente bloquea el botón de cobro y ofrece confirmarlo',
      (WidgetTester tester) async {
        final FakePaymentsService fake = FakePaymentsService(
          total: _totalPrueba,
          pagos: <Payment>[
            pagoDePrueba(
              id: 12,
              monto: 450,
              metodo: 'MERCADO_PAGO',
              estado: 'PENDIENTE',
              referenciaExterna: 'SIM-MOT-7-12',
              enlacePago:
                  'https://sandbox.mercadopago.com.mx/motorix/checkout',
              modoPasarela: 'simulado',
            ),
          ],
        );
        await pumpDetalle(tester, service: fake);

        expect(find.byKey(const Key('cobro-pendiente')), findsOneWidget);
        expect(
          find.byKey(const Key('boton-registrar-pago')),
          findsNothing,
          reason: 'con un cobro pendiente no se admite otro intento (FR-005)',
        );
        expect(find.textContaining('SIM-MOT-7-12'), findsOneWidget);
        expect(find.byKey(const Key('aprobar-12')), findsOneWidget);
        expect(find.byKey(const Key('rechazar-12')), findsOneWidget);
        expect(find.byKey(const Key('cancelar-cobro-12')), findsOneWidget);
      },
    );

    testWidgets(
      'marcar como aprobado liquida la orden y refresca el estado',
      (WidgetTester tester) async {
        final FakePaymentsService fake = FakePaymentsService(
          total: _totalPrueba,
          pagos: <Payment>[
            pagoDePrueba(
              id: 13,
              monto: 450,
              metodo: 'MERCADO_PAGO',
              estado: 'PENDIENTE',
              referenciaExterna: 'SIM-MOT-7-13',
              modoPasarela: 'simulado',
            ),
          ],
        );
        await pumpDetalle(tester, service: fake);

        await tester.tap(find.byKey(const Key('aprobar-13')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();

        expect(fake.ultimoConfirmado, isNotNull);
        expect(fake.ultimoConfirmado!.id, 13);
        expect(fake.ultimoConfirmado!.estado, 'PAGADO');

        expect(find.text('Pagado'), findsOneWidget);
        expect(find.byKey(const Key('aprobar-13')), findsNothing);
        expect(
          find.byKey(const Key('boton-registrar-pago')),
          findsNothing,
          reason: 'el pago aprobado liquida la orden (FR-004)',
        );
        expect(
          find.text('Orden liquidada: ya tiene su pago aprobado.'),
          findsOneWidget,
        );
        expect(
          find.text('Cobro confirmado: el pago queda aprobado.'),
          findsOneWidget,
        );

        // Deja pasar la duración del snackbar para no encolar avisos.
        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'marcar como rechazado libera la orden para otro intento (HU3-3)',
      (WidgetTester tester) async {
        final FakePaymentsService fake = FakePaymentsService(
          total: _totalPrueba,
          pagos: <Payment>[
            pagoDePrueba(
              id: 14,
              monto: 450,
              metodo: 'MERCADO_PAGO',
              estado: 'PENDIENTE',
              referenciaExterna: 'SIM-MOT-7-14',
              modoPasarela: 'simulado',
            ),
          ],
        );
        await pumpDetalle(tester, service: fake);

        await tester.tap(find.byKey(const Key('rechazar-14')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();

        expect(fake.ultimoConfirmado!.estado, 'RECHAZADO');

        expect(find.text('Rechazado'), findsOneWidget);
        expect(find.byKey(const Key('cobro-pendiente')), findsNothing);
        expect(
          find.byKey(const Key('boton-registrar-pago')),
          findsOneWidget,
          reason: 'sin cobro aprobado ni pendiente la orden admite otro cobro',
        );

        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'cancelar el cobro pendiente deja el pago cancelado (HU3-4)',
      (WidgetTester tester) async {
        final FakePaymentsService fake = FakePaymentsService(
          total: _totalPrueba,
          pagos: <Payment>[
            pagoDePrueba(
              id: 15,
              monto: 450,
              metodo: 'MERCADO_PAGO',
              estado: 'PENDIENTE',
              referenciaExterna: 'SIM-MOT-7-15',
              modoPasarela: 'simulado',
            ),
          ],
        );
        await pumpDetalle(tester, service: fake);

        await tester.tap(find.byKey(const Key('cancelar-cobro-15')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();

        expect(fake.ultimoConfirmado!.estado, 'CANCELADO');
        expect(find.text('Cancelado'), findsOneWidget);
        expect(find.byKey(const Key('cobro-pendiente')), findsNothing);
        expect(
          find.byKey(const Key('boton-registrar-pago')),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'el mecánico no ve las acciones de confirmación (FR-003, RN-15)',
      (WidgetTester tester) async {
        await pumpDetalle(
          tester,
          service: FakePaymentsService(
            total: _totalPrueba,
            pagos: <Payment>[
              pagoDePrueba(
                id: 16,
                metodo: 'MERCADO_PAGO',
                estado: 'PENDIENTE',
              ),
            ],
          ),
          rol: Rol.mechanic,
        );

        expect(find.text('Cobro y pago'), findsNothing);
        expect(find.byKey(const Key('aprobar-16')), findsNothing);
        expect(find.byKey(const Key('rechazar-16')), findsNothing);
      },
    );
  });
}
