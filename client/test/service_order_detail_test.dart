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
import 'package:motorix_client/providers/service_orders_provider.dart';
import 'package:motorix_client/screens/service_order_detail_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/service_orders_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_parts_service.dart';

/// Catálogo que ve el selector de refacciones de la orden (US7): la primera
/// tiene stock y la segunda está agotada para comprobar que no se puede elegir.
final List<Part> _catalogoPrueba = <Part>[
  parteDePrueba(id: 901, codigo: 'BUJ-1', nombre: 'Juego de bujías'),
  parteDePrueba(id: 902, codigo: 'FIL-1', nombre: 'Filtro de aceite', stockActual: 0),
];

/// Servicio falso con el contenido de la orden en memoria: no se abre
/// ninguna conexión y cada operación queda registrada para las aserciones.
class _ServiceOrdersServiceFake extends ServiceOrdersService {
  _ServiceOrdersServiceFake({this.ordenActual, this.contenidoFailure})
      : super(ApiClient());

  /// Orden que devuelve `detail` y que cada operación va actualizando.
  ServiceOrder? ordenActual;

  /// Si se define, las operaciones de contenido lanzan este error (p. ej. el
  /// `409` de una orden entregada, FR-016).
  ApiException? contenidoFailure;

  final List<({String texto, bool borrador})> diagnosticos =
      <({String texto, bool borrador})>[];
  final List<({String descripcion, int duracionMinutos, num? precio})>
      altasServicio = <({
        String descripcion,
        int duracionMinutos,
        num? precio,
      })>[];
  final List<int> bajasServicio = <int>[];
  final List<({int partId, int cantidad})> altasRepuesto =
      <({int partId, int cantidad})>[];
  final List<int> bajasRepuesto = <int>[];
  final List<String> recomendaciones = <String>[];

  void _fallarSiCorresponde() {
    if (contenidoFailure != null) {
      throw contenidoFailure!;
    }
  }

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
  Future<void> saveDiagnosis({
    required int id,
    required String texto,
    required bool borrador,
  }) async {
    _fallarSiCorresponde();
    diagnosticos.add((texto: texto, borrador: borrador));
    ordenActual = _copiaContenido(
      ordenActual ?? _orden(id: id),
      diagnostico: texto,
      diagnosticoBorrador: borrador,
    );
  }

  @override
  Future<void> addService({
    required int id,
    required String descripcion,
    required int duracionMinutos,
    num? precio,
  }) async {
    _fallarSiCorresponde();
    altasServicio.add((
      descripcion: descripcion,
      duracionMinutos: duracionMinutos,
      precio: precio,
    ));
    final ServiceOrder base = ordenActual ?? _orden(id: id);
    final int servicioId = 500 + altasServicio.length;
    ordenActual = _copiaContenido(
      base,
      servicios: <OrderServiceItem>[
        ...base.servicios,
        OrderServiceItem(
          id: servicioId,
          descripcion: descripcion,
          manoDeObra: OrderLabor(
            id: servicioId + 1000,
            duracionMinutos: duracionMinutos,
            precio: precio,
          ),
        ),
      ],
    );
  }

  @override
  Future<void> removeService({
    required int id,
    required int servicioId,
  }) async {
    _fallarSiCorresponde();
    bajasServicio.add(servicioId);
    final ServiceOrder base = ordenActual ?? _orden(id: id);
    ordenActual = _copiaContenido(
      base,
      servicios: base.servicios
          .where((OrderServiceItem s) => s.id != servicioId)
          .toList(),
    );
  }

  @override
  Future<void> addPart({
    required int id,
    required int partId,
    required int cantidad,
  }) async {
    _fallarSiCorresponde();
    altasRepuesto.add((partId: partId, cantidad: cantidad));
    final ServiceOrder base = ordenActual ?? _orden(id: id);
    ordenActual = _copiaContenido(
      base,
      repuestos: <OrderPart>[
        ...base.repuestos,
        OrderPart(
          id: 700 + altasRepuesto.length,
          // El backend copia el nombre del catálogo al dar de alta (R-06).
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
    _fallarSiCorresponde();
    bajasRepuesto.add(repuestoId);
    final ServiceOrder base = ordenActual ?? _orden(id: id);
    ordenActual = _copiaContenido(
      base,
      repuestos:
          base.repuestos.where((OrderPart p) => p.id != repuestoId).toList(),
    );
  }

  @override
  Future<void> saveRecommendations({
    required int id,
    required String texto,
  }) async {
    _fallarSiCorresponde();
    recomendaciones.add(texto);
    ordenActual = _copiaContenido(
      ordenActual ?? _orden(id: id),
      recomendaciones: texto,
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
  String? diagnostico,
  bool diagnosticoBorrador = false,
  String? recomendaciones,
  List<Map<String, dynamic>> servicios = const <Map<String, dynamic>>[],
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
    'fechaIngreso': '2026-10-13',
    'kilometrajeEntrada': 45200,
    'mecanicoId': mecanicoId,
    'mecanico': mecanico,
    'diagnostico': diagnostico,
    'diagnosticoBorrador': diagnosticoBorrador,
    'recomendaciones': recomendaciones,
    'servicios': servicios,
    'repuestos': repuestos,
  });
}

ServiceOrder _copiaContenido(
  ServiceOrder base, {
  String? diagnostico,
  bool? diagnosticoBorrador,
  String? recomendaciones,
  List<OrderServiceItem>? servicios,
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
    diagnostico: diagnostico ?? base.diagnostico,
    diagnosticoBorrador: diagnosticoBorrador ?? base.diagnosticoBorrador,
    recomendaciones: recomendaciones ?? base.recomendaciones,
    servicios: servicios ?? base.servicios,
    repuestos: repuestos ?? base.repuestos,
    historial: base.historial,
  );
}

/// Nombre del catálogo para una fila creada por el fake (R-06).
String _nombreRefaccion(int partId) {
  for (final Part parte in _catalogoPrueba) {
    if (parte.id == partId) {
      return parte.nombre;
    }
  }
  return 'Refacción $partId';
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
  }) async {
    // Altura amplia para que los paneles del contenido quepan sin scroll.
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
      ordenActual: orden ?? _orden(id: 7),
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
              service: FakePartsService(parts: _catalogoPrueba),
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

  group('ServiceOrderDetailScreen — contenido de la orden (US4)', () {
    testWidgets(
      'el diagnóstico en borrador se marca y se precarga en el campo (FR-011)',
      (WidgetTester tester) async {
        await pumpDetail(
          tester,
          rol: Rol.mechanic,
          orden: _orden(
            diagnostico: 'Pastillas delanteras al límite',
            diagnosticoBorrador: true,
          ),
        );

        expect(find.text('Borrador sin confirmar'), findsOneWidget);
        expect(
          find.text('Pastillas delanteras al límite'),
          findsOneWidget,
          reason: 'el texto guardado debe precargarse en el campo',
        );
      },
    );

    testWidgets(
      'el mecánico guarda el diagnóstico como borrador (FR-011)',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(tester, rol: Rol.mechanic);

        await tester.enterText(
          find.byKey(const Key('campo-diagnostico')),
          'Fuga de aceite en el motor',
        );
        await tester.tap(find.text('Guardar borrador'));
        await tester.pumpAndSettle();

        expect(
          estado.fake.diagnosticos,
          <({String texto, bool borrador})>[
            (texto: 'Fuga de aceite en el motor', borrador: true),
          ],
        );
        expect(
          find.text('Diagnóstico guardado como borrador.'),
          findsOneWidget,
        );
        expect(find.text('Borrador sin confirmar'), findsOneWidget);
      },
    );

    testWidgets(
      'guardar y continuar confirma el diagnóstico y quita la marca de borrador',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(
          tester,
          rol: Rol.mechanic,
          orden: _orden(
            diagnostico: 'Pastillas delanteras al límite',
            diagnosticoBorrador: true,
          ),
        );

        await tester.enterText(
          find.byKey(const Key('campo-diagnostico')),
          'Pastillas delanteras al límite, cambiarlas',
        );
        await tester.tap(find.text('Guardar y continuar'));
        await tester.pumpAndSettle();

        expect(estado.fake.diagnosticos.last.borrador, isFalse);
        expect(find.text('Diagnóstico guardado.'), findsOneWidget);
        expect(find.text('Borrador sin confirmar'), findsNothing);
      },
    );

    testWidgets(
      'agrega un servicio con duración y precio y limpia los campos',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(tester, rol: Rol.mechanic);

        await tester.enterText(
          find.byKey(const Key('campo-servicio')),
          'Cambio de pastillas',
        );
        await tester.enterText(find.byKey(const Key('campo-duracion')), '45');
        await tester.enterText(find.byKey(const Key('campo-precio')), '350');
        await tester.tap(find.text('Agregar servicio'));
        await tester.pumpAndSettle();

        expect(
          estado.fake.altasServicio,
          <({String descripcion, int duracionMinutos, num? precio})>[
            (descripcion: 'Cambio de pastillas', duracionMinutos: 45, precio: 350),
          ],
        );
        expect(find.text('Servicio agregado a la orden.'), findsOneWidget);
        expect(find.text('Cambio de pastillas'), findsOneWidget);
        expect(
          find.text('45 min de mano de obra · \$350.00'),
          findsOneWidget,
          reason: 'la mano de obra creada debe listarse con su precio',
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('campo-servicio')))
              .controller!
              .text,
          isEmpty,
          reason: 'el campo debe limpiarse después de agregar',
        );
      },
    );

    testWidgets(
      'valida en cliente la duración del servicio antes de enviarla',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(tester, rol: Rol.mechanic);

        await tester.enterText(
          find.byKey(const Key('campo-servicio')),
          'Servicio sin duración',
        );
        await tester.tap(find.text('Agregar servicio'));
        await tester.pumpAndSettle();

        expect(estado.fake.altasServicio, isEmpty);
        expect(
          find.textContaining('Revisa la descripción, la duración'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'da de baja un servicio con confirmación previa (Principio VIII)',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(
          tester,
          rol: Rol.mechanic,
          orden: _orden(
            servicios: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 55,
                'descripcion': 'Alineación',
                'manoDeObra': <String, dynamic>{
                  'id': 155,
                  'duracionMinutos': 30,
                  'precio': 250,
                },
              },
            ],
          ),
        );

        await tester.tap(find.byTooltip('Eliminar servicio'));
        await tester.pumpAndSettle();

        // Confirmación obligatoria antes de la baja destructiva.
        expect(find.text('Eliminar servicio'), findsOneWidget);
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        expect(estado.fake.bajasServicio, <int>[55]);
        expect(find.text('Servicio eliminado.'), findsOneWidget);
        expect(find.text('Sin servicios registrados.'), findsOneWidget);
      },
    );

    testWidgets(
      'agrega una refacción del catálogo con su cantidad (US7)',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(tester, rol: Rol.mechanic);

        // El selector empieza sin elegir y ofrece solo el catálogo activo.
        expect(find.text('Selecciona una refacción'), findsOneWidget);

        await tester.tap(find.byKey(const Key('selector-refaccion')));
        await tester.pumpAndSettle();

        // El stock visible acompaña a cada refacción del menú.
        expect(find.text('Juego de bujías (BUJ-1) · stock 6'), findsWidgets);
        expect(find.text('Filtro de aceite (FIL-1) · stock 0'), findsWidgets);

        await tester.tap(find.text('Juego de bujías (BUJ-1) · stock 6').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('campo-cantidad')), '4');
        await tester.tap(find.text('Agregar refacción'));
        await tester.pumpAndSettle();

        expect(
          estado.fake.altasRepuesto,
          <({int partId, int cantidad})>[
            (partId: 901, cantidad: 4),
          ],
        );
        expect(
          find.text('Refacción registrada en la orden.'),
          findsOneWidget,
        );
        expect(find.text('4 × Juego de bujías'), findsOneWidget);
      },
    );

    testWidgets(
      'da de baja una refacción con confirmación obligatoria (FR-026)',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(
          tester,
          rol: Rol.mechanic,
          orden: _orden(
            repuestos: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 44,
                'descripcion': 'Filtro de aceite',
                'cantidad': 2,
              },
            ],
          ),
        );

        await tester.tap(find.byTooltip('Eliminar refacción'));
        await tester.pumpAndSettle();
        expect(find.text('Eliminar refacción'), findsOneWidget);
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();

        expect(estado.fake.bajasRepuesto, <int>[44]);
        expect(find.text('Refacción retirada de la orden.'), findsOneWidget);
        expect(find.text('Sin refacciones registradas.'), findsOneWidget);
      },
    );

    testWidgets(
      'guarda las recomendaciones para la entrega (FR-013)',
      (WidgetTester tester) async {
        final ({_ServiceOrdersServiceFake fake, ServiceOrdersProvider provider})
            estado = await pumpDetail(tester, rol: Rol.mechanic);

        await tester.enterText(
          find.byKey(const Key('campo-recomendaciones')),
          'Revisar discos en 5,000 km',
        );
        await tester.tap(find.text('Guardar recomendaciones'));
        await tester.pumpAndSettle();

        expect(estado.fake.recomendaciones, <String>[
          'Revisar discos en 5,000 km',
        ]);
        expect(find.text('Recomendaciones guardadas.'), findsOneWidget);
      },
    );

    testWidgets(
      'el administrador también registra el contenido de la orden',
      (WidgetTester tester) async {
        await pumpDetail(tester, rol: Rol.admin);

        expect(find.text('Guardar borrador'), findsOneWidget);
        expect(find.text('Agregar servicio'), findsOneWidget);
        expect(find.text('Agregar refacción'), findsOneWidget);
        expect(find.text('Guardar recomendaciones'), findsOneWidget);
      },
    );

    testWidgets(
      'recepción solo registra refacciones, sin diagnóstico ni servicios',
      (WidgetTester tester) async {
        await pumpDetail(
          tester,
          rol: Rol.receptionist,
          orden: _orden(diagnostico: 'Todo en orden'),
        );

        expect(find.text('Diagnóstico'), findsOneWidget);
        expect(find.text('Todo en orden'), findsOneWidget);
        expect(find.text('Guardar borrador'), findsNothing);
        expect(find.text('Guardar y continuar'), findsNothing);
        expect(find.text('Agregar servicio'), findsNothing);
        expect(find.text('Guardar recomendaciones'), findsNothing);
        expect(find.byTooltip('Eliminar servicio'), findsNothing);
        // Las refacciones de la orden las manejan los tres roles (FR-027).
        expect(find.text('Agregar refacción'), findsOneWidget);
      },
    );

    testWidgets(
      'una orden entregada no ofrece acciones de contenido (FR-016)',
      (WidgetTester tester) async {
        await pumpDetail(
          tester,
          rol: Rol.mechanic,
          orden: _orden(estado: 'ENTREGADO', diagnostico: 'Trabajo concluido'),
        );

        expect(find.text('Trabajo concluido'), findsOneWidget);
        expect(find.text('Guardar borrador'), findsNothing);
        expect(find.text('Agregar servicio'), findsNothing);
        expect(find.text('Agregar refacción'), findsNothing);
        expect(find.text('Guardar recomendaciones'), findsNothing);
        expect(find.byTooltip('Eliminar servicio'), findsNothing);
        expect(find.byTooltip('Eliminar refacción'), findsNothing);
      },
    );

    testWidgets(
      'el 409 del backend al guardar el diagnóstico se muestra en el aviso',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
          ordenActual: _orden(id: 7),
          contenidoFailure: ApiException(
            'Una orden entregada no admite cambios en su contenido',
            codigo: 'ORDEN_ENTREGADA',
            statusCode: 409,
          ),
        );
        final ServiceOrdersProvider provider = ServiceOrdersProvider(
          api: ApiClient(),
          service: fake,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(
                create: (_) => _AuthProviderFake(api: ApiClient(), rol: Rol.mechanic),
              ),
              ChangeNotifierProvider<ServiceOrdersProvider>.value(
                value: provider,
              ),
              ChangeNotifierProvider<PartsProvider>(
                create: (_) => PartsProvider(
                  api: ApiClient(),
                  service: FakePartsService(parts: _catalogoPrueba),
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

        await tester.enterText(
          find.byKey(const Key('campo-diagnostico')),
          'Cambio tardío',
        );
        await tester.tap(find.text('Guardar y continuar'));
        await tester.pumpAndSettle();

        expect(
          find.text('Una orden entregada no admite cambios en su contenido'),
          findsOneWidget,
        );
        expect(fake.diagnosticos, isEmpty, reason: 'no debe guardarse nada');
      },
    );
  });
}
