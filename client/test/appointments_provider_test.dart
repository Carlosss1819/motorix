import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/appointment.dart';
import 'package:motorix_client/providers/appointments_provider.dart';
import 'package:motorix_client/providers/load_status.dart';
import 'package:motorix_client/providers/shell_provider.dart';
import 'package:motorix_client/screens/appointments_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/appointments_service.dart';
import 'package:motorix_client/utils/app_theme.dart';
import 'package:motorix_client/utils/formatters.dart';

/// Servicio falso con datos en memoria: no se abre ninguna conexión.
class _AppointmentsServiceFake extends AppointmentsService {
  _AppointmentsServiceFake({
    this.page,
    this.paginaRespuesta,
    this.failure,
    this.createFailure,
  }) : super(ApiClient());

  /// Página que devuelve `list`.
  AppointmentPage? page;

  /// Si se define, la respuesta usa esta página en lugar de la pedida.
  int? paginaRespuesta;

  /// Si se define, `list` lanza este error.
  ApiException? failure;

  /// Si se define, `create` lanza este error (por ejemplo el 409 de FR-008).
  ApiException? createFailure;

  int listados = 0;
  String? ultimaFecha;
  String? ultimoEstado;
  String? ultimoBuscar;
  int? ultimaPagina;
  bool? ultimoConfirmar;
  int cancelaciones = 0;
  String? ultimoMotivoCancelacion;
  int recepciones = 0;

  AppointmentPage _respuesta(int pagina) {
    final AppointmentPage base = page ??
        const AppointmentPage(
          elementos: <Appointment>[],
          pagina: 1,
          paginas: 1,
          total: 0,
        );
    return AppointmentPage(
      elementos: base.elementos,
      pagina: paginaRespuesta ?? pagina,
      paginas: base.paginas,
      total: base.total,
    );
  }

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
    listados += 1;
    ultimaFecha = fecha;
    ultimoEstado = estado;
    ultimoBuscar = buscar;
    ultimaPagina = pagina;
    if (failure != null) {
      throw failure!;
    }
    return _respuesta(pagina);
  }

  @override
  Future<Appointment> create({
    required int clienteId,
    required int vehiculoId,
    required String fecha,
    required String hora,
    required String motivo,
    bool confirmar = false,
  }) async {
    ultimoConfirmar = confirmar;
    if (createFailure != null) {
      throw createFailure!;
    }
    return _cita();
  }

  @override
  Future<Appointment> cancel({required int id, String motivo = ''}) async {
    cancelaciones += 1;
    ultimoMotivoCancelacion = motivo;
    return _cita(estado: 'CANCELADA');
  }

  @override
  Future<ReceivedAppointment> receive({required int id}) async {
    recepciones += 1;
    return ReceivedAppointment.fromJson(<String, dynamic>{
      'cita': <String, dynamic>{'id': id, 'estado': 'RECIBIDA'},
      'precargaOrden': <String, dynamic>{
        'clienteId': 1,
        'vehiculoId': 1,
        'motivo': 'Revisión de frenos',
        'citaId': id,
      },
    });
  }
}

Appointment _cita({
  int id = 1,
  String cliente = 'Juan Pérez',
  String estado = 'PROGRAMADA',
  String fecha = '2026-10-13',
  String hora = '10:30',
}) {
  return Appointment.fromJson(<String, dynamic>{
    'id': id,
    'clienteId': 1,
    'cliente': cliente,
    'vehiculoId': 1,
    'vehiculo': 'Nissan Versa 2020',
    'placas': 'ABC1234',
    'fecha': fecha,
    'hora': hora,
    'motivo': 'Revisión de frenos',
    'estado': estado,
    'motivoCancelacion': '',
    'ordenId': null,
  });
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppointmentsProvider', () {
    test('arranca sin citas, en estado ocioso y con el filtro de hoy', () {
      final AppointmentsProvider provider = AppointmentsProvider(
        api: ApiClient(),
        service: _AppointmentsServiceFake(),
      );

      expect(provider.status, LoadStatus.idle);
      expect(provider.items, isEmpty);
      expect(provider.total, 0);
      expect(provider.fecha, hoyIso(), reason: 'la HU2 abre en el día de hoy');
      expect(provider.estado, kSinEstadoCita);
      expect(provider.pagina, 1);
      expect(provider.conflictoHorario, isNull);
    });

    test('carga la página del backend y expone el paginado', () async {
      final _AppointmentsServiceFake fake = _AppointmentsServiceFake(
        paginaRespuesta: 2,
        page: AppointmentPage(
          elementos: <Appointment>[
            _cita(),
            _cita(id: 2, cliente: 'Ana Ruiz', estado: 'CANCELADA'),
          ],
          pagina: 2,
          paginas: 3,
          total: 24,
        ),
      );
      final AppointmentsProvider provider = AppointmentsProvider(
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
      expect(fake.ultimaFecha, hoyIso(), reason: 'debe pedir el día de hoy');
      expect(provider.error, isNull);
    });

    test('el filtro por estado vuelve a la primera página', () async {
      final _AppointmentsServiceFake fake = _AppointmentsServiceFake(
        page: const AppointmentPage(
          elementos: <Appointment>[],
          pagina: 3,
          paginas: 3,
          total: 30,
        ),
      );
      final AppointmentsProvider provider = AppointmentsProvider(
        api: ApiClient(),
        service: fake,
      );

      await provider.load();
      await provider.goToPage(3);
      expect(provider.pagina, 3);

      await provider.setEstado('CANCELADA');

      expect(provider.estado, 'CANCELADA');
      expect(provider.pagina, 1, reason: 'el filtro debe volver al inicio');
      expect(fake.ultimaPagina, 1, reason: 'la consulta debe pedir la página 1');
      expect(fake.ultimoEstado, 'CANCELADA');
    });

    test('el filtro por fecha consulta el día elegido', () async {
      final _AppointmentsServiceFake fake = _AppointmentsServiceFake();
      final AppointmentsProvider provider = AppointmentsProvider(
        api: ApiClient(),
        service: fake,
      );

      await provider.setFecha('2027-03-15');

      expect(provider.fecha, '2027-03-15');
      expect(fake.ultimaFecha, '2027-03-15');
      expect(fake.ultimaPagina, 1);
    });

    test('la misma búsqueda no repite la consulta al backend', () async {
      final _AppointmentsServiceFake fake = _AppointmentsServiceFake();
      final AppointmentsProvider provider = AppointmentsProvider(
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
      final _AppointmentsServiceFake fake = _AppointmentsServiceFake(
        failure: ApiException(
          'No se pudo conectar con el servidor.',
          statusCode: 500,
        ),
      );
      final AppointmentsProvider provider = AppointmentsProvider(
        api: ApiClient(),
        service: fake,
      );

      await provider.load();

      expect(provider.status, LoadStatus.error);
      expect(provider.items, isEmpty);
      expect(provider.error, 'No se pudo conectar con el servidor.');
    });

    test('guarda el conflicto de horario del 409 y lo limpia al confirmar',
        () async {
      const String mensaje =
          'Ya existe una cita para este vehículo el 2027-03-15 a las 10:30';
      final _AppointmentsServiceFake fake = _AppointmentsServiceFake(
        createFailure: ApiException(
          mensaje,
          codigo: 'CITA_CONFLICTO_HORARIO',
          statusCode: 409,
        ),
      );
      final AppointmentsProvider provider = AppointmentsProvider(
        api: ApiClient(),
        service: fake,
      );

      await expectLater(
        provider.create(
          clienteId: 1,
          vehiculoId: 1,
          fecha: '2027-03-15',
          hora: '10:30',
          motivo: 'Revisión de frenos',
        ),
        throwsA(isA<ApiException>()),
      );

      expect(provider.hayConflictoHorario, isTrue);
      expect(provider.conflictoHorario, mensaje);

      // El reenvío con confirmar: true guarda la cita (FR-008).
      fake.createFailure = null;
      await provider.create(
        clienteId: 1,
        vehiculoId: 1,
        fecha: '2027-03-15',
        hora: '10:30',
        motivo: 'Revisión de frenos',
        confirmar: true,
      );

      expect(fake.ultimoConfirmar, isTrue);
      expect(
        provider.conflictoHorario,
        isNull,
        reason: 'el reenvío confirmado limpia el conflicto',
      );
    });

    test('cancelar una cita refresca el listado con el motivo enviado',
        () async {
      final _AppointmentsServiceFake fake = _AppointmentsServiceFake();
      final AppointmentsProvider provider = AppointmentsProvider(
        api: ApiClient(),
        service: fake,
      );

      final Appointment cancelada = await provider.cancel(
        id: 1,
        motivo: 'El cliente no pudo asistir',
      );

      expect(cancelada.estado, 'CANCELADA');
      expect(fake.cancelaciones, 1);
      expect(fake.ultimoMotivoCancelacion, 'El cliente no pudo asistir');
      expect(fake.listados, 1, reason: 'cancelar debe recargar la lista');
    });

    test('recibir devuelve la precarga y refresca el listado', () async {
      final _AppointmentsServiceFake fake = _AppointmentsServiceFake();
      final AppointmentsProvider provider = AppointmentsProvider(
        api: ApiClient(),
        service: fake,
      );

      final ReceivedAppointment recibida = await provider.receive(id: 7);

      expect(recibida.citaId, 7);
      expect(recibida.estado, 'RECIBIDA');
      expect(recibida.motivo, 'Revisión de frenos');
      expect(recibida.citaOrigen, 7);
      expect(fake.recepciones, 1);
      expect(fake.listados, 1, reason: 'recibir debe recargar la lista');
    });
  });

  group('AppointmentsScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      _AppointmentsServiceFake fake,
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
            ChangeNotifierProvider<AppointmentsProvider>(
              create: (_) =>
                  AppointmentsProvider(api: ApiClient(), service: fake),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: AppointmentsScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
      'lista las citas con hora, cliente, estado y sus acciones',
      (WidgetTester tester) async {
        final _AppointmentsServiceFake fake = _AppointmentsServiceFake(
          page: AppointmentPage(
            elementos: <Appointment>[
              _cita(),
              _cita(
                id: 2,
                cliente: 'Ana Ruiz',
                estado: 'CANCELADA',
                hora: '12:00',
              ),
            ],
            pagina: 1,
            paginas: 1,
            total: 2,
          ),
        );

        await pumpScreen(tester, fake);

        expect(find.text('10:30'), findsOneWidget);
        expect(find.text('12:00'), findsOneWidget);
        expect(find.text('Juan Pérez'), findsOneWidget);
        expect(find.text('Ana Ruiz'), findsOneWidget);
        expect(find.text('Programada'), findsOneWidget);
        expect(find.text('Cancelada'), findsOneWidget);
        expect(find.text('2 citas'), findsOneWidget);
        expect(find.text('Nueva cita'), findsWidgets);
        expect(
          find.text('Recibir'),
          findsOneWidget,
          reason: 'solo la cita programada se puede recibir',
        );
        expect(
          find.text('Cancelar'),
          findsOneWidget,
          reason: 'solo la cita programada se puede cancelar',
        );
      },
    );

    testWidgets(
      'muestra el estado vacío del día cuando no hay citas',
      (WidgetTester tester) async {
        final _AppointmentsServiceFake fake = _AppointmentsServiceFake();

        await pumpScreen(tester, fake);

        expect(
          find.text('No hay citas para el ${Formatters.date(hoyIso())}.'),
          findsOneWidget,
        );
        expect(find.text('Nueva cita'), findsWidgets);
      },
    );
  });
}
