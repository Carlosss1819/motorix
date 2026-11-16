// Pruebas de la pantalla del ticket y de los botones de ticket del detalle
// de la orden (US4, FR-007/FR-008/FR-009, Sprint 4): el comprobante se
// muestra con folio y todos los campos del contrato, la orden sin pago aprobado
// muestra el aviso del backend y el detalle alterna entre «Generar ticket» y
// «Ver ticket». Fuente de verdad: contracts/tickets.md.
// Convenciones: viewport 1280×3000 y GoogleFonts sin descargas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/app_user.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/models/order_total.dart';
import 'package:motorix_client/models/payment.dart';
import 'package:motorix_client/models/service_order.dart';
import 'package:motorix_client/models/ticket.dart';
import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/providers/parts_provider.dart';
import 'package:motorix_client/providers/payment_provider.dart';
import 'package:motorix_client/providers/service_orders_provider.dart';
import 'package:motorix_client/providers/ticket_provider.dart';
import 'package:motorix_client/screens/service_order_detail_screen.dart';
import 'package:motorix_client/screens/ticket_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/service_orders_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_parts_service.dart';
import 'fake_payments_service.dart';
import 'fake_tickets_service.dart';

/// Sesión simulada de recepción (el ticket es de recepción y administración).
class _AuthProviderFake extends AuthProvider {
  _AuthProviderFake({required super.api, required String rol})
      : _user = AppUser(
          id: 2,
          username: 'recepcion',
          email: 'recepcion@motorix.local',
          rol: rol,
        );

  final AppUser _user;

  @override
  AppUser? get user => _user;

  @override
  bool get isAuthenticated => true;
}

/// Servicio de órdenes falso para el detalle, sin red.
class _OrdenesFake extends ServiceOrdersService {
  _OrdenesFake() : super(ApiClient());

  @override
  Future<ServiceOrder> detail(int id) async => ServiceOrder.fromJson(
        <String, dynamic>{
          'id': 7,
          'clienteId': 1,
          'cliente': 'María López',
          'telefono': '55-1111-2222',
          'vehiculoId': 7,
          'vehiculo': 'Nissan Versa 2020',
          'placas': 'ABC-123-D',
          'estado': 'TERMINADO',
          'motivoVisita': 'Cambio de aceite',
          'fechaIngreso': '2026-10-13',
          'kilometrajeEntrada': 84500,
          'mecanicoId': null,
          'mecanico': null,
        },
      );

  @override
  Future<List<MechanicOption>> listMechanics() async =>
      const <MechanicOption>[];
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Pantalla de ticket con su proveedor y servicio falso.
  Future<void> pumpTicket(
    WidgetTester tester, {
    required FakeTicketsService service,
    TicketScreenArgs args = const TicketScreenArgs(ordenId: 7),
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TicketProvider>(
            create: (_) => TicketProvider(api: ApiClient(), service: service),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: TicketScreen(args: args)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Detalle de la orden liquidada con los cuatro proveedores del bloque de
  /// cobro y ruta para abrir el ticket (como en la app real).
  Future<FakeTicketsService> pumpDetalle(
    WidgetTester tester, {
    required FakeTicketsService tickets,
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
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
                ServiceOrdersProvider(api: ApiClient(), service: _OrdenesFake()),
          ),
          ChangeNotifierProvider<PartsProvider>(
            create: (_) =>
                PartsProvider(api: ApiClient(), service: FakePartsService()),
          ),
          ChangeNotifierProvider<PaymentsProvider>(
            create: (_) => PaymentsProvider(
              api: ApiClient(),
              service: FakePaymentsService(
                pagos: <Payment>[
                  pagoDePrueba(id: 1, monto: 450, estado: 'PAGADO'),
                ],
                total: const OrderTotal(
                  ordenId: 7,
                  subtotalManoDeObra: 450,
                  subtotalRefacciones: 0,
                  total: 450,
                ),
              ),
            ),
          ),
          ChangeNotifierProvider<TicketProvider>(
            create: (_) => TicketProvider(api: ApiClient(), service: tickets),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ServiceOrderDetailScreen(orderId: 7)),
          onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(
              body: TicketScreen(
                args: settings.arguments is TicketScreenArgs
                    ? settings.arguments! as TicketScreenArgs
                    : const TicketScreenArgs(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return tickets;
  }

  group('TicketScreen — comprobante (US4, FR-007)', () {
    testWidgets(
      'muestra el comprobante completo con folio, datos y desglose',
      (WidgetTester tester) async {
        final FakeTicketsService service = FakeTicketsService(
          consulta: TicketLookup(existe: true, ticket: ticketDePrueba()),
        );
        await pumpTicket(tester, service: service);

        // Encabezado y folio (SC-003: formato T000000-AAAA).
        expect(find.byKey(const Key('ticket-folio')), findsOneWidget);
        expect(find.text('T000003-2026'), findsOneWidget);
        expect(find.text('Ticket de servicio'), findsOneWidget);

        // Taller, cliente y vehículo (FR-007).
        expect(find.text('Motorix'), findsOneWidget);
        expect(find.text('Av. Ejemplo 123, Col. Centro'), findsOneWidget);
        expect(find.text('55-0000-0000'), findsOneWidget);
        expect(find.text('María López'), findsOneWidget);
        expect(find.text('Nissan Versa 2020'), findsOneWidget);
        expect(find.text('ABC-123-D'), findsOneWidget);
        expect(find.text('84,500 km'), findsOneWidget);

        // Servicios con sus refacciones anidadas.
        expect(find.text('Cambio de aceite'), findsOneWidget);
        expect(find.text('Mano de obra: \$450.00'), findsOneWidget);
        expect(
          find.text(
            '4 × FIL-A01 · Aceite 5W-30 — \$180.00 · Subtotal \$720.00',
          ),
          findsOneWidget,
        );

        // Subtotales, total y pago.
        expect(find.text('Subtotal mano de obra'), findsOneWidget);
        expect(find.text('\$450.00'), findsWidgets);
        expect(find.byKey(const Key('ticket-total')), findsOneWidget);
        expect(find.text('\$1,170.00'), findsOneWidget);
        expect(find.text('Efectivo'), findsOneWidget);
        expect(find.text('2026-10-14'), findsOneWidget);
        expect(find.text('recepcion'), findsOneWidget);

        // CA-5: botón de imprimir que delega en el diálogo del navegador.
        expect(find.widgetWithText(FilledButton, 'Imprimir'), findsOneWidget);

        // El servicio se consultó una sola vez (no se duplicó nada).
        expect(service.llamadasConsulta, 1);
        expect(service.llamadasGeneracion, 0);
      },
    );

    testWidgets(
      'una orden sin pago avisa que primero debe registrarse el pago (E5)',
      (WidgetTester tester) async {
        final FakeTicketsService service = FakeTicketsService(
          errorGeneracion: ApiException(
            'La orden no tiene un pago aprobado: primero debe registrarse '
            'el pago',
            codigo: 'TICKET_REQUIERE_PAGO',
            statusCode: 409,
          ),
        );
        await pumpTicket(tester, service: service);

        expect(
          find.textContaining('primero debe registrarse el pago'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ticket-folio')), findsNothing);
        expect(service.llamadasGeneracion, 1);
      },
    );

    testWidgets(
      'el botón Imprimir abre el diálogo con la opción de copiar el texto',
      (WidgetTester tester) async {
        final FakeTicketsService service = FakeTicketsService(
          consulta: TicketLookup(existe: true, ticket: ticketDePrueba()),
        );
        await pumpTicket(tester, service: service);

        await tester.tap(find.widgetWithText(FilledButton, 'Imprimir'));
        await tester.pumpAndSettle();

        expect(find.text('Imprimir comprobante'), findsOneWidget);
        expect(find.text('Copiar texto'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Cerrar'));
        await tester.pumpAndSettle();

        expect(find.text('Imprimir comprobante'), findsNothing);
      },
    );
  });

  group('ServiceOrderDetailScreen — botones de ticket (US4, T042)', () {
    testWidgets(
      'una orden liquidada sin ticket ofrece generarlo y lo abre',
      (WidgetTester tester) async {
        final FakeTicketsService service = await pumpDetalle(
          tester,
          tickets: FakeTicketsService(),
        );

        expect(find.byKey(const Key('boton-generar-ticket')), findsOneWidget);
        expect(find.byKey(const Key('boton-ver-ticket')), findsNothing);

        await tester.tap(find.byKey(const Key('boton-generar-ticket')));
        await tester.pumpAndSettle();

        // La pantalla de ticket genera el comprobante y lo muestra.
        expect(find.byKey(const Key('ticket-folio')), findsOneWidget);
        expect(find.text('T000003-2026'), findsOneWidget);
        expect(service.llamadasGeneracion, 1);
      },
    );

    testWidgets(
      'con el ticket ya existe ofrece verlo sin volver a generarlo',
      (WidgetTester tester) async {
        final FakeTicketsService service = await pumpDetalle(
          tester,
          tickets: FakeTicketsService(
            consulta: TicketLookup(
              existe: true,
              ticket: ticketDePrueba(folio: 'T000009-2026'),
            ),
          ),
        );

        expect(find.byKey(const Key('boton-ver-ticket')), findsOneWidget);
        expect(find.byKey(const Key('boton-generar-ticket')), findsNothing);

        await tester.tap(find.byKey(const Key('boton-ver-ticket')));
        await tester.pumpAndSettle();

        expect(find.text('T000009-2026'), findsOneWidget);
        expect(service.llamadasGeneracion, 0);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Sprint 5 (US4, FR-018, FR-020, FR-022, FR-033): marcas del ticket con los
  // tokens `warning` y `danger` y la lista «Tickets anteriores».
  // -------------------------------------------------------------------------
  group('TicketScreen — marcas del Sprint 5', () {
    MotorixColors colores() => AppTheme.light().extension<MotorixColors>()!;

    Color colorDelChip(WidgetTester tester, String llave) {
      final Text texto = tester.widget<Text>(
        find.descendant(of: find.byKey(Key(llave)), matching: find.byType(Text)),
      );
      return texto.style!.color!;
    }

    testWidgets('chip_Formato_anterior_con_warning_y_texto_de_ayuda', (
      WidgetTester tester,
    ) async {
      await pumpTicket(
        tester,
        service: FakeTicketsService(),
        args: TicketScreenArgs(
          ticket: ticketDePrueba(formatoAnterior: true),
        ),
      );

      expect(find.text('Formato anterior'), findsOneWidget);
      expect(colorDelChip(tester, 'chip-formato-anterior'), colores().warning);
      expect(find.text(kAyudaFormatoAnterior), findsOneWidget);
      expect(find.text('Pago anulado'), findsNothing);
    });

    testWidgets('chip_Pago_anulado_con_danger_y_su_aviso', (
      WidgetTester tester,
    ) async {
      await pumpTicket(
        tester,
        service: FakeTicketsService(),
        args: TicketScreenArgs(
          ticket: ticketDePrueba(
            pagoAnulado: true,
            vigente: false,
            estadoPago: 'ANULADO',
          ),
        ),
      );

      expect(find.text('Pago anulado'), findsOneWidget);
      expect(colorDelChip(tester, 'chip-pago-anulado'), colores().danger);
      expect(find.text(kAvisoPagoAnulado), findsOneWidget);
    });

    testWidgets('aviso_El_desglose_no_coincide_con_lo_cobrado', (
      WidgetTester tester,
    ) async {
      await pumpTicket(
        tester,
        service: FakeTicketsService(),
        args: TicketScreenArgs(
          ticket: ticketDePrueba(
            formatoAnterior: true,
            desgloseNoCoincide: true,
            nota: 'El desglose no coincide con lo cobrado',
            subtotalManoDeObra: 1090,
            subtotalRefacciones: 0,
            total: 1390,
          ),
        ),
      );

      expect(find.text('El desglose no coincide con lo cobrado'), findsOneWidget);
      expect(find.text('\$1,390.00'), findsOneWidget);
    });

    testWidgets('sin_precio_registrado_en_la_linea_con_warning', (
      WidgetTester tester,
    ) async {
      await pumpTicket(
        tester,
        service: FakeTicketsService(),
        args: TicketScreenArgs(
          ticket: ticketDePrueba(
            servicios: const <TicketServiceLine>[
              TicketServiceLine(
                descripcion: 'Revisión',
                manoDeObra: 0,
                avisoManoDeObra: 'sin precio registrado',
                refacciones: <TicketPartLine>[
                  TicketPartLine(
                    nombre: 'Filtro heredado',
                    cantidad: 1,
                    precioUnitario: 0,
                    subtotal: 0,
                    aviso: 'sin precio registrado',
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final Finder avisos = find.text('sin precio registrado');
      expect(avisos, findsNWidgets(2));
      expect(tester.widget<Text>(avisos.first).style!.color, colores().warning);
    });

    testWidgets('el_ticket_vigente_no_muestra_marcas', (
      WidgetTester tester,
    ) async {
      await pumpTicket(
        tester,
        service: FakeTicketsService(),
        args: TicketScreenArgs(ticket: ticketDePrueba()),
      );

      expect(find.text('Formato anterior'), findsNothing);
      expect(find.text('Pago anulado'), findsNothing);
      expect(find.text('El desglose no coincide con lo cobrado'), findsNothing);
    });
  });

  group('ServiceOrderDetailScreen — tickets anteriores (Sprint 5)', () {
    testWidgets(
      'lista_Tickets_anteriores_con_folio_fecha_y_chip_Pago_anulado',
      (WidgetTester tester) async {
        final FakeTicketsService service = await pumpDetalle(
          tester,
          tickets: FakeTicketsService(
            consulta: TicketLookup(
              existe: true,
              ticket: ticketDePrueba(id: 12, folio: 'T000012-2026'),
              tickets: const <TicketSummary>[
                TicketSummary(
                  id: 12,
                  folio: 'T000012-2026',
                  pagoId: 8,
                  emitidoEn: '2026-11-16 12:00:00',
                  vigente: true,
                ),
                TicketSummary(
                  id: 9,
                  folio: 'T000009-2026',
                  pagoId: 5,
                  emitidoEn: '2026-11-15 09:30:00',
                  pagoAnulado: true,
                ),
              ],
            ),
          ),
        );

        expect(find.text('Tickets anteriores'), findsOneWidget);
        expect(find.text('T000009-2026 · 2026-11-15 09:30:00'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('ticket-anterior-9')),
            matching: find.text('Pago anulado'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ticket-anterior-12')), findsNothing);

        // «Ver ticket» abre el vigente.
        await tester.tap(find.byKey(const Key('boton-ver-ticket')));
        await tester.pumpAndSettle();
        expect(find.text('T000012-2026'), findsOneWidget);
        expect(service.llamadasGeneracion, 0);
      },
    );

    testWidgets('sin_tickets_anteriores_no_se_dibuja_la_lista', (
      WidgetTester tester,
    ) async {
      await pumpDetalle(
        tester,
        tickets: FakeTicketsService(
          consulta: TicketLookup(existe: true, ticket: ticketDePrueba()),
        ),
      );
      expect(find.text('Tickets anteriores'), findsNothing);
    });
  });
}
