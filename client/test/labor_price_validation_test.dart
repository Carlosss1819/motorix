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
import 'package:motorix_client/providers/ticket_provider.dart';
import 'package:motorix_client/screens/service_order_detail_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/service_orders_service.dart';
import 'package:motorix_client/utils/app_theme.dart';
import 'package:motorix_client/utils/validators.dart';

import 'fake_parts_service.dart';
import 'fake_payments_service.dart';
import 'fake_tickets_service.dart';

/// Pruebas del precio de la mano de obra en el detalle de la orden (Sprint 5,
/// FR-032): la misma regla que el servidor (número ≥ 0, máximo 2 decimales y
/// hasta 999,999.99).

class _OrdenesFake extends ServiceOrdersService {
  _OrdenesFake() : super(ApiClient());

  final List<num?> preciosEnviados = <num?>[];

  @override
  Future<ServiceOrder> detail(int id) async => ServiceOrder.fromJson(
        <String, dynamic>{
          'id': id,
          'clienteId': 1,
          'cliente': 'Juan Pérez',
          'telefono': '7221234567',
          'vehiculoId': 1,
          'vehiculo': 'Nissan Versa 2020',
          'placas': 'ABC1234',
          'estado': 'RECIBIDO',
          'motivoVisita': 'Revisión',
          'fechaIngreso': '2026-11-16',
          'kilometrajeEntrada': 1000,
          'mecanicoId': 3,
          'mecanico': 'mecanico',
          'servicios': <Map<String, dynamic>>[],
          'repuestos': <Map<String, dynamic>>[],
        },
      );

  @override
  Future<List<MechanicOption>> listMechanics() async =>
      const <MechanicOption>[];

  @override
  Future<void> addService({
    required int id,
    required String descripcion,
    required int duracionMinutos,
    num? precio,
    // Sprint 7 (FR-010): parámetro opcional nuevo del servicio real.
    int? tipoServicioId,
  }) async {
    preciosEnviados.add(precio);
  }
}

class _AuthAdmin extends AuthProvider {
  _AuthAdmin() : super(api: ApiClient());

  @override
  AppUser? get user => const AppUser(
        id: 1,
        username: 'admin',
        email: 'admin@motorix.local',
        rol: Rol.admin,
      );

  @override
  bool get isAuthenticated => true;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<_OrdenesFake> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final _OrdenesFake fake = _OrdenesFake();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _AuthAdmin()),
          ChangeNotifierProvider<ServiceOrdersProvider>(
            create: (_) =>
                ServiceOrdersProvider(api: ApiClient(), service: fake),
          ),
          ChangeNotifierProvider<PartsProvider>(
            create: (_) =>
                PartsProvider(api: ApiClient(), service: FakePartsService()),
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
    return fake;
  }

  Future<void> agregar(WidgetTester tester, String precio) async {
    await tester.enterText(find.byKey(const Key('campo-servicio')), 'Frenos');
    await tester.enterText(find.byKey(const Key('campo-duracion')), '30');
    await tester.enterText(find.byKey(const Key('campo-precio')), precio);
    await tester.tap(find.text('Agregar servicio'));
    await tester.pumpAndSettle();
  }

  testWidgets('rechaza_tres_decimales', (WidgetTester tester) async {
    final _OrdenesFake fake = await abrir(tester);
    await agregar(tester, '120.555');
    expect(
      find.text(
        'El campo el precio de la mano de obra debe tener máximo 2 decimales.',
      ),
      findsOneWidget,
    );
    expect(fake.preciosEnviados, isEmpty);
  });

  testWidgets('rechaza_un_precio_negativo', (WidgetTester tester) async {
    final _OrdenesFake fake = await abrir(tester);
    await agregar(tester, '-10');
    expect(
      find.text('El campo el precio de la mano de obra no puede ser negativo.'),
      findsOneWidget,
    );
    expect(fake.preciosEnviados, isEmpty);
  });

  testWidgets('rechaza_mas_de_999999_99', (WidgetTester tester) async {
    final _OrdenesFake fake = await abrir(tester);
    await agregar(tester, '1000000');
    expect(
      find.text(
        'El campo el precio de la mano de obra no puede ser mayor a 999,999.99.',
      ),
      findsOneWidget,
    );
    expect(fake.preciosEnviados, isEmpty);
  });

  testWidgets('acepta_un_precio_con_dos_decimales', (WidgetTester tester) async {
    final _OrdenesFake fake = await abrir(tester);
    await agregar(tester, '350.50');
    expect(fake.preciosEnviados, <num?>[350.5]);
  });

  test('el_validador_comparte_la_regla_del_servidor', () {
    expect(Validators.price('', 'el precio'), isNull);
    expect(Validators.price('0', 'el precio'), isNull);
    expect(Validators.price('999999.99', 'el precio'), isNull);
    expect(Validators.price('abc', 'el precio'), isNotNull);
    expect(Validators.price('10.005', 'el precio'), isNotNull);
  });
}
