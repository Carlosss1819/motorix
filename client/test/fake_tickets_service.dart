import 'package:motorix_client/models/ticket.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/tickets_service.dart';

/// Servicio de tickets falso para pruebas (US4): devuelve la consulta y la
/// generación que se le asignen sin abrir ninguna conexión y deja a la vista
/// las llamadas recibidas.
class FakeTicketsService extends TicketsService {
  FakeTicketsService({
    this.consulta,
    this.ticket,
    this.errorConsulta,
    this.errorGeneracion,
  }) : super(ApiClient());

  /// Respuesta de `GET /api/tickets/orden/:ordenId`; sin valor responde
  /// `existe: false` (la orden aún no tiene comprobante).
  TicketLookup? consulta;

  /// Comprobante que responde `POST /api/tickets`; sin valor se genera el de
  /// [ticketDePrueba].
  Ticket? ticket;

  /// Fallos opcionales lanzados como [ApiException]: por ejemplo el
  /// `409 TICKET_REQUIERE_PAGO` de una orden sin pago aprobado.
  ApiException? errorConsulta;
  ApiException? errorGeneracion;

  /// Veces que se consultó la existencia y que se generó el ticket.
  int llamadasConsulta = 0;
  int llamadasGeneracion = 0;

  @override
  Future<TicketLookup> fetchTicketByOrder({required int ordenId}) async {
    llamadasConsulta += 1;
    final ApiException? fallo = errorConsulta;
    if (fallo != null) {
      throw fallo;
    }
    return consulta ?? TicketLookup(existe: false, ticket: null);
  }

  @override
  Future<Ticket> generate({required int ordenId}) async {
    llamadasGeneracion += 1;
    final ApiException? fallo = errorGeneracion;
    if (fallo != null) {
      throw fallo;
    }
    return ticket ?? ticketDePrueba(ordenId: ordenId);
  }

  @override
  Future<Ticket> fetchTicket({required int id}) async {
    return ticket ?? ticketDePrueba(id: id);
  }
}

/// Fábrica compacta de un ticket para las pruebas, con el formato completo
/// del contrato (FR-007).
Ticket ticketDePrueba({
  int id = 3,
  String folio = 'T000003-2026',
  int ordenId = 7,
  int pagoId = 5,
  String emitidoPor = 'recepcion',
  String emitidoEn = '2026-10-14 11:02:00',
  String fecha = '2026-10-14',
  String metodoPago = 'EFECTIVO',
  String estadoPago = 'PAGADO',
  num subtotalManoDeObra = 450,
  num subtotalRefacciones = 720,
  num total = 1170,
  WorkshopInfo taller = const WorkshopInfo(
    nombre: 'Motorix',
    direccion: 'Av. Ejemplo 123, Col. Centro',
    telefono: '55-0000-0000',
  ),
  TicketClient cliente = const TicketClient(
    id: 4,
    nombre: 'María López',
    telefono: '55-1111-2222',
  ),
  TicketVehicle vehiculo = const TicketVehicle(
    id: 7,
    marca: 'Nissan',
    modelo: 'Versa',
    anio: 2020,
    placas: 'ABC-123-D',
    kilometraje: 84500,
  ),
  List<TicketServiceLine>? servicios,
}) =>
    Ticket(
      id: id,
      folio: folio,
      ordenId: ordenId,
      pagoId: pagoId,
      emitidoPor: emitidoPor,
      emitidoEn: emitidoEn,
      taller: taller,
      cliente: cliente,
      vehiculo: vehiculo,
      servicios: servicios ??
          <TicketServiceLine>[
            const TicketServiceLine(
              descripcion: 'Cambio de aceite',
              manoDeObra: 450,
              refacciones: <TicketPartLine>[
                TicketPartLine(
                  codigo: 'FIL-A01',
                  nombre: 'Aceite 5W-30',
                  cantidad: 4,
                  precioUnitario: 180,
                  subtotal: 720,
                ),
              ],
            ),
          ],
      subtotalManoDeObra: subtotalManoDeObra,
      subtotalRefacciones: subtotalRefacciones,
      total: total,
      metodoPago: metodoPago,
      estadoPago: estadoPago,
      fecha: fecha,
    );
