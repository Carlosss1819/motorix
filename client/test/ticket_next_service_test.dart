// Pruebas del próximo servicio en el ticket (Sprint 7, US8, FR-012/FR-013):
// se muestra cuando la copia lo trae y no aparece en tickets sin tipos ni en
// los anteriores al sprint.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/ticket.dart';
import 'package:motorix_client/providers/ticket_provider.dart';
import 'package:motorix_client/screens/ticket_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_tickets_service.dart';

Map<String, dynamic> _ticketJson({List<Map<String, dynamic>>? proximos}) => <String, dynamic>{
      'id': 5, 'folio': 'T202611-0005', 'ordenId': 7, 'pagoId': 3, 'emitidoPor': 'recepcion',
      'emitidoEn': '2026-11-26 10:00:00',
      'taller': <String, dynamic>{'nombre': 'Motorix', 'direccion': 'Av. Ejemplo 123', 'telefono': '55-0000-0000'},
      'cliente': <String, dynamic>{'id': 1, 'nombre': 'María López', 'telefono': '55-1111-2222'},
      'vehiculo': <String, dynamic>{'id': 7, 'marca': 'Nissan', 'modelo': 'Versa', 'anio': 2020, 'placas': 'ABC-123', 'kilometraje': 10000},
      'servicios': <Map<String, dynamic>>[],
      'subtotalManoDeObra': 500, 'subtotalRefacciones': 0, 'total': 500,
      'metodoPago': 'EFECTIVO', 'estadoPago': 'PAGADO', 'fecha': '2026-11-26', 'formatoVersion': 2,
      'proximosServicios': ?proximos,
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> montar(WidgetTester tester, Ticket ticket) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeTicketsService service = FakeTicketsService(ticket: ticket);
    await tester.pumpWidget(
      ChangeNotifierProvider<TicketProvider>(
        create: (_) => TicketProvider(api: ApiClient(), service: service),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TicketScreen(args: TicketScreenArgs(ticketId: 5))),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  test('test_un_ticket_anterior_sin_el_campo_queda_con_lista_vacia', () {
    expect(Ticket.fromJson(_ticketJson()).proximosServicios, isEmpty);
  });

  testWidgets('test_muestra_el_proximo_servicio_por_tipo', (WidgetTester tester) async {
    await montar(
      tester,
      Ticket.fromJson(_ticketJson(proximos: <Map<String, dynamic>>[
        <String, dynamic>{'tipoServicio': 'Cambio de aceite', 'fecha': '2027-05-25', 'kilometraje': 15000},
        <String, dynamic>{'tipoServicio': 'Revisión de frenos', 'fecha': '2027-11-26', 'kilometraje': null},
      ])),
    );

    expect(find.byKey(const Key('ticket-proximo-servicio')), findsOneWidget);
    expect(find.text('Próximo servicio'), findsOneWidget);
    expect(find.text('25/05/2027 o 15,000 km, lo que ocurra primero'), findsOneWidget);
    expect(find.text('26/11/2027'), findsOneWidget);
  });

  testWidgets('test_sin_proximos_servicios_no_aparece_la_seccion', (WidgetTester tester) async {
    await montar(tester, Ticket.fromJson(_ticketJson(proximos: <Map<String, dynamic>>[])));
    expect(find.byKey(const Key('ticket-proximo-servicio')), findsNothing);
  });
}
