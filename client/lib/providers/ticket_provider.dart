import 'package:flutter/foundation.dart';

import '../models/ticket.dart';
import '../services/api_client.dart';
import '../services/tickets_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Estado del ticket de una orden (Sprint 4, US4):
///
/// - [lookup]/[existe]: consulta `GET /api/tickets/orden/:ordenId` que decide
///   el botón «Generar ticket» o «Ver ticket» en el detalle (T042).
/// - [status]/[ticket]: comprobante para `TicketScreen`, con sus estados de
///   carga y error; un `409 TICKET_REQUIERE_PAGO` se muestra tal cual (E5 del
///   quickstart: «primero debe registrarse el pago»).
class TicketProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  TicketProvider({required ApiClient api, TicketsService? service})
      : _service = service ?? TicketsService(api);

  final TicketsService _service;

  LoadStatus _status = LoadStatus.idle;
  LoadStatus _lookup = LoadStatus.idle;
  Ticket? _ticket;
  bool _existe = false;
  String? _error;

  LoadStatus get status => _status;
  LoadStatus get lookup => _lookup;
  Ticket? get ticket => _ticket;
  bool get existe => _existe;
  String? get error => _error;

  /// GET /api/tickets/orden/:ordenId: ¿la orden ya tiene comprobante?
  /// No interrumpe la pantalla si falla: solo oculta el botón de ticket.
  Future<void> consultarExistencia(int ordenId) async {
    _lookup = LoadStatus.loading;
    notifyListeners();
    try {
      final TicketLookup resultado =
          await _service.fetchTicketByOrder(ordenId: ordenId);
      _existe = resultado.existe;
      _ticket = resultado.ticket;
      _lookup = LoadStatus.ready;
    } on ApiException catch (e) {
      _error = e.mensaje;
      _lookup = LoadStatus.error;
    } catch (_) {
      _error = AppMessages.unexpectedError;
      _lookup = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Abre el comprobante de la orden en `TicketScreen`: usa el ticket si ya
  /// existe y, si no, lo genera (el backend resuelve la idempotencia). Un
  /// `409` por orden sin pago aprobado se publica como [error] en español.
  Future<void> abrir(int ordenId) async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final TicketLookup resultado =
          await _service.fetchTicketByOrder(ordenId: ordenId);
      _existe = resultado.existe;
      _ticket = resultado.ticket ??
          await _service.generate(ordenId: ordenId);
      _lookup = LoadStatus.ready;
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Muestra un comprobante ya cargado (por ejemplo, el que devuelve
  /// [consultarExistencia]), sin volver a pedirlo.
  void mostrar(Ticket ticket) {
    _ticket = ticket;
    _existe = true;
    _error = null;
    _lookup = LoadStatus.ready;
    _status = LoadStatus.ready;
    notifyListeners();
  }

  /// Reinicia el estado al salir de la pantalla de ticket.
  void limpiar() {
    _status = LoadStatus.idle;
    _ticket = null;
    _error = null;
    notifyListeners();
  }
}
