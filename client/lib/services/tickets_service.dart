import '../models/ticket.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones del recurso `/api/tickets` (HU4; contrato:
/// contracts/tickets.md). Generación y consulta para ADMIN y RECEPTIONIST
/// (FR-003); la generación es idempotente (HU4-2) y exige un pago aprobado
/// (FR-009), que el backend devuelve como `409 TICKET_REQUIERE_PAGO`.
class TicketsService {
  TicketsService(this._api);

  final ApiClient _api;

  /// POST /api/tickets — genera el ticket de la orden pagada (201) o
  /// devuelve el existente con su folio original (200).
  Future<Ticket> generate({required int ordenId}) async {
    final dynamic data = await _api.post(
      '/tickets',
      body: <String, Object?>{'ordenId': ordenId},
    );
    return Ticket.fromJson(asMap(data));
  }

  /// GET /api/tickets/:id — comprobante por su identificador.
  Future<Ticket> fetchTicket({required int id}) async {
    final dynamic data = await _api.get('/tickets/$id');
    return Ticket.fromJson(asMap(data));
  }

  /// GET /api/tickets/orden/:ordenId — consulta si la orden ya tiene ticket
  /// (`existe`) y su comprobante, para el botón «Ver/Generar ticket».
  Future<TicketLookup> fetchTicketByOrder({required int ordenId}) async {
    final dynamic data = await _api.get('/tickets/orden/$ordenId');
    final Map<String, dynamic> json = asMap(data);
    final Object? ticketJson = json['ticket'];
    return TicketLookup(
      existe: asBool(json['existe']),
      ticket: ticketJson is Map ? Ticket.fromJson(asMap(ticketJson)) : null,
    );
  }
}
