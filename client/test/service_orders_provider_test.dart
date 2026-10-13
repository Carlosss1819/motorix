import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/service_order.dart';
import 'package:motorix_client/providers/load_status.dart';
import 'package:motorix_client/providers/service_orders_provider.dart';
import 'package:motorix_client/providers/shell_provider.dart';
import 'package:motorix_client/screens/service_orders_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/service_orders_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

/// Servicio falso con datos en memoria: no se abre ninguna conexión.
class _ServiceOrdersServiceFake extends ServiceOrdersService {
  _ServiceOrdersServiceFake({this.page, this.paginaRespuesta, this.failure})
      : super(ApiClient());

  /// Página que devuelve `list`.
  ServiceOrderPage? page;

  /// Si se define, la respuesta usa esta página en lugar de la pedida (como
  /// haría un backend que recorta el rango).
  int? paginaRespuesta;

  /// Si se define, `list` lanza este error.
  ApiException? failure;

  /// Cuántas veces se consultó el listado.
  int listados = 0;

  /// Últimos filtros recibidos, para comprobar el paginado.
  String? ultimoBuscar;
  String? ultimoEstado;
  int? ultimaPagina;

  @override
  Future<ServiceOrderPage> list({
    String buscar = '',
    String estado = '',
    int pagina = 1,
    int porPagina = 10,
  }) async {
    listados++;
    ultimoBuscar = buscar;
    ultimoEstado = estado;
    ultimaPagina = pagina;
    final ApiException? error = failure;
    if (error != null) {
      throw error;
    }
    final ServiceOrderPage base =
        page ??
        const ServiceOrderPage(
          elementos: <ServiceOrder>[],
          pagina: 1,
          paginas: 1,
          total: 0,
        );
    return ServiceOrderPage(
      elementos: base.elementos,
      pagina: paginaRespuesta ?? pagina,
      paginas: base.paginas,
      total: base.total,
    );
  }
}

ServiceOrder _orden({
  int id = 4,
  String cliente = 'Juan Pérez',
  String estado = 'DIAGNOSTICO',
}) {
  return ServiceOrder.fromJson(<String, dynamic>{
    'id': id,
    'clienteId': 1,
    'cliente': cliente,
    'vehiculoId': 1,
    'vehiculo': 'Nissan Versa 2020',
    'placas': 'ABC1234',
    'estado': estado,
    'motivoVisita': 'Revisión de frenos',
    'fechaIngreso': '2026-10-13',
    'kilometrajeEntrada': 45200,
    'mecanicoId': null,
    'mecanico': null,
  });
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ServiceOrdersProvider', () {
    test('arranca sin órdenes y en estado ocioso', () {
      final ServiceOrdersProvider provider = ServiceOrdersProvider(
        api: ApiClient(),
        service: _ServiceOrdersServiceFake(),
      );

      expect(provider.status, LoadStatus.idle);
      expect(provider.items, isEmpty);
      expect(provider.total, 0);
      expect(provider.estado, kTodosLosEstados);
      expect(provider.pagina, 1);
    });

    test('carga la página del backend y expone el paginado', () async {
      final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
        paginaRespuesta: 2,
        page: ServiceOrderPage(
          elementos: <ServiceOrder>[_orden(), _orden(id: 5, cliente: 'Ana Ruiz')],
          pagina: 2,
          paginas: 3,
          total: 24,
        ),
      );
      final ServiceOrdersProvider provider = ServiceOrdersProvider(
        api: ApiClient(),
        service: fake,
      );

      await provider.load();

      expect(provider.status, LoadStatus.ready);
      expect(provider.items, hasLength(2));
      expect(provider.items.first.cliente, 'Juan Pérez');
      expect(provider.pagina, 2);
      expect(provider.paginas, 3);
      expect(provider.total, 24);
      expect(provider.error, isNull);
    });

    test('el filtro de estado vuelve a la primera página', () async {
      final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
        page: const ServiceOrderPage(
          elementos: <ServiceOrder>[],
          pagina: 3,
          paginas: 3,
          total: 30,
        ),
      );
      final ServiceOrdersProvider provider = ServiceOrdersProvider(
        api: ApiClient(),
        service: fake,
      );

      await provider.load();
      await provider.goToPage(3);
      expect(provider.pagina, 3);

      await provider.setEstado('DIAGNOSTICO');

      expect(provider.estado, 'DIAGNOSTICO');
      expect(provider.pagina, 1, reason: 'el filtro debe volver al inicio');
      expect(fake.ultimaPagina, 1, reason: 'la consulta debe pedir la página 1');
      expect(fake.ultimoEstado, 'DIAGNOSTICO');
    });

    test('la misma búsqueda no repite la consulta al backend', () async {
      final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake();
      final ServiceOrdersProvider provider = ServiceOrdersProvider(
        api: ApiClient(),
        service: fake,
      );

      await provider.setBuscar('ABC1234');
      final int despuesDeLaPrimera = fake.listados;
      await provider.setBuscar('ABC1234');

      expect(despuesDeLaPrimera, 1);
      expect(fake.listados, 1, reason: 'no debe consultar de nuevo');
      expect(fake.ultimoBuscar, 'ABC1234');
    });

    test('muestra el mensaje en español cuando el backend falla', () async {
      final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
        failure: ApiException(
          'El kilometraje de entrada es menor al de la última orden.',
          statusCode: 400,
        ),
      );
      final ServiceOrdersProvider provider = ServiceOrdersProvider(
        api: ApiClient(),
        service: fake,
      );

      await provider.load();

      expect(provider.status, LoadStatus.error);
      expect(provider.items, isEmpty);
      expect(
        provider.error,
        'El kilometraje de entrada es menor al de la última orden.',
      );
    });
  });

  group('ServiceOrdersScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      _ServiceOrdersServiceFake fake,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShellProvider>(
              create: (_) => ShellProvider(initialWidth: 1280),
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
      'lista las órdenes con su cliente, estado y contador',
      (WidgetTester tester) async {
        final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake(
          page: ServiceOrderPage(
            elementos: <ServiceOrder>[
              _orden(),
              _orden(id: 7, cliente: 'Ana Ruiz', estado: 'RECIBIDO'),
            ],
            pagina: 1,
            paginas: 1,
            total: 2,
          ),
        );

        await pumpScreen(tester, fake);

        expect(find.text('#4'), findsOneWidget);
        expect(find.text('#7'), findsOneWidget);
        expect(find.text('Juan Pérez'), findsOneWidget);
        expect(find.text('Ana Ruiz'), findsOneWidget);
        expect(find.text('Diagnóstico'), findsOneWidget);
        expect(find.text('Recibido'), findsOneWidget);
        expect(find.text('2 órdenes'), findsOneWidget);
        expect(find.text('Registrar orden'), findsWidgets);
      },
    );

    testWidgets(
      'muestra un estado vacío amigable cuando no hay órdenes',
      (WidgetTester tester) async {
        final _ServiceOrdersServiceFake fake = _ServiceOrdersServiceFake();

        await pumpScreen(tester, fake);

        expect(
          find.text(
            'Todavía no hay órdenes de servicio. Registra la primera para '
            'empezar.',
          ),
          findsOneWidget,
        );
        expect(find.text('Registrar orden'), findsWidgets);
      },
    );
  });
}
