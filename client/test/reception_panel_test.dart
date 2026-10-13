import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/appointment.dart';
import 'package:motorix_client/models/service_order.dart';
import 'package:motorix_client/providers/appointments_provider.dart';
import 'package:motorix_client/providers/service_orders_provider.dart';
import 'package:motorix_client/screens/reception_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/appointments_service.dart';
import 'package:motorix_client/services/service_orders_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

/// Servicio falso de citas: devuelve la página cargada y recuerda la fecha
/// pedida para verificar que el panel consulta el día de hoy (R-09).
class _AppointmentsServiceFake extends AppointmentsService {
  _AppointmentsServiceFake({this.page, this.failure}) : super(ApiClient());

  AppointmentPage? page;
  ApiException? failure;
  String? ultimaFecha;

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
    if (failure != null) {
      throw failure!;
    }
    ultimaFecha = fecha;
    return page ??
        const AppointmentPage(
          elementos: <Appointment>[],
          pagina: 1,
          paginas: 1,
          total: 0,
        );
  }
}

/// Servicio falso de órdenes: solo expone las abiertas del panel (R-09) y
/// cuenta cuántas veces se pidieron.
class _ServiceOrdersServiceFake extends ServiceOrdersService {
  _ServiceOrdersServiceFake({this.page, this.failure}) : super(ApiClient());

  ServiceOrderPage? page;
  ApiException? failure;
  int aperturasListOpen = 0;

  @override
  Future<ServiceOrderPage> listOpen({int pagina = 1, int porPagina = 10}) async {
    if (failure != null) {
      throw failure!;
    }
    aperturasListOpen += 1;
    return page ??
        const ServiceOrderPage(
          elementos: <ServiceOrder>[],
          pagina: 1,
          paginas: 1,
          total: 0,
        );
  }
}

Appointment _cita({
  String hora = '09:30',
  String cliente = 'Juan Pérez',
  String estado = 'PROGRAMADA',
}) {
  return Appointment.fromJson(<String, dynamic>{
    'id': 1,
    'clienteId': 1,
    'cliente': cliente,
    'vehiculoId': 1,
    'vehiculo': 'Nissan Versa 2020',
    'placas': 'ABC1234',
    'fecha': hoyIso(),
    'hora': hora,
    'motivo': 'Revisión de frenos',
    'estado': estado,
  });
}

ServiceOrder _ordenAbierta({
  int id = 7,
  String estado = 'EN_REPARACION',
  String? mecanico = 'mecanico',
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
    'fechaIngreso': '2026-10-16',
    'kilometrajeEntrada': 45200,
    'mecanicoId': mecanico == null ? null : 3,
    'mecanico': mecanico,
  });
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<
    ({_AppointmentsServiceFake citas, _ServiceOrdersServiceFake ordenes})
  >
  pumpPanel(
    WidgetTester tester, {
    AppointmentPage? citasPage,
    ApiException? citasFailure,
    ServiceOrderPage? ordenesPage,
    ApiException? ordenesFailure,
  }) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final _AppointmentsServiceFake citas = _AppointmentsServiceFake(
      page: citasPage,
      failure: citasFailure,
    );
    final _ServiceOrdersServiceFake ordenes = _ServiceOrdersServiceFake(
      page: ordenesPage,
      failure: ordenesFailure,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppointmentsProvider>(
            create: (_) =>
                AppointmentsProvider(api: ApiClient(), service: citas),
          ),
          ChangeNotifierProvider<ServiceOrdersProvider>(
            create: (_) =>
                ServiceOrdersProvider(api: ApiClient(), service: ordenes),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ReceptionScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return (citas: citas, ordenes: ordenes);
  }

  group('ReceptionScreen — panel de recepción (US6, R-09)', () {
    testWidgets(
      'muestra las citas del día con hora, cliente, vehículo y estado',
      (WidgetTester tester) async {
        final ({
          _AppointmentsServiceFake citas,
          _ServiceOrdersServiceFake ordenes,
        }) estado = await pumpPanel(
          tester,
          citasPage: AppointmentPage(
            elementos: <Appointment>[_cita()],
            pagina: 1,
            paginas: 1,
            total: 1,
          ),
        );

        expect(estado.citas.ultimaFecha, hoyIso(), reason: 'R-09: fecha de hoy');
        expect(find.text('09:30 · Juan Pérez'), findsOneWidget);
        expect(find.text('Nissan Versa 2020 · ABC1234'), findsOneWidget);
        expect(find.text('Programada'), findsOneWidget);
        expect(estado.ordenes.aperturasListOpen, 1);
      },
    );

    testWidgets(
      'muestra las órdenes abiertas con su estado y mecánico asignado',
      (WidgetTester tester) async {
        final ({
          _AppointmentsServiceFake citas,
          _ServiceOrdersServiceFake ordenes,
        }) estado = await pumpPanel(
          tester,
          ordenesPage: ServiceOrderPage(
            elementos: <ServiceOrder>[_ordenAbierta()],
            pagina: 1,
            paginas: 1,
            total: 1,
          ),
        );

        expect(estado.ordenes.aperturasListOpen, 1);
        expect(find.text('#7 · Revisión de frenos'), findsOneWidget);
        expect(find.text('Nissan Versa 2020 · ABC1234'), findsOneWidget);
        expect(find.text('En reparación'), findsOneWidget);
        expect(find.text('mecanico'), findsOneWidget);
      },
    );

    testWidgets(
      'un día sin citas ni órdenes muestra "sin actividades" y no un error',
      (WidgetTester tester) async {
        await pumpPanel(tester);

        expect(
          find.text(
            'Sin actividades por hoy: no hay citas ni órdenes abiertas.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Ocurrió'), findsNothing);
      },
    );

    testWidgets(
      'el fallo de una fuente no oculta la otra (estado de error)',
      (WidgetTester tester) async {
        await pumpPanel(
          tester,
          citasFailure: ApiException(
            'No se pudo conectar con el servidor. Verifica que el servicio '
            'esté disponible e inténtalo de nuevo.',
            statusCode: 500,
          ),
          ordenesPage: ServiceOrderPage(
            elementos: <ServiceOrder>[_ordenAbierta()],
            pagina: 1,
            paginas: 1,
            total: 1,
          ),
        );

        expect(
          find.textContaining(
            'No se pudo conectar con el servidor',
            findRichText: true,
          ),
          findsWidgets,
        );
        expect(find.text('#7 · Revisión de frenos'), findsOneWidget);
        expect(find.text('Reintentar'), findsWidgets);
      },
    );

    testWidgets(
      'Reintentar vuelve a consultar las dos fuentes',
      (WidgetTester tester) async {
        final ({
          _AppointmentsServiceFake citas,
          _ServiceOrdersServiceFake ordenes,
        }) estado = await pumpPanel(
          tester,
          citasFailure: ApiException('Fallo temporal', statusCode: 500),
        );

        expect(find.text('Fallo temporal'), findsOneWidget);

        estado.citas.failure = null;
        await tester.tap(find.text('Reintentar').first);
        await tester.pumpAndSettle();

        expect(find.text('Fallo temporal'), findsNothing);
        expect(
          find.text(
            'Sin actividades por hoy: no hay citas ni órdenes abiertas.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
