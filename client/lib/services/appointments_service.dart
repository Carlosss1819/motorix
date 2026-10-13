import '../models/appointment.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones del recurso `/api/appointments` (US2; contrato:
/// contracts/appointments.md).
class AppointmentsService {
  AppointmentsService(this._api);

  final ApiClient _api;

  /// GET /api/appointments?fecha=&desde=&hasta=&estado=&buscar=&pagina=&porPagina=
  ///
  /// `fecha` es un día exacto y `desde`/`hasta` un rango; la búsqueda cubre
  /// placas y nombre del cliente. Al listar, el backend marca como
  /// `NO_PRESENTADA` las citas vencidas (FR-006, R-06).
  Future<AppointmentPage> list({
    String fecha = '',
    String desde = '',
    String hasta = '',
    String estado = '',
    String buscar = '',
    int pagina = 1,
    int porPagina = 10,
  }) async {
    final dynamic data = await _api.get(
      '/appointments',
      query: <String, String>{
        'fecha': fecha,
        'desde': desde,
        'hasta': hasta,
        'estado': estado,
        'buscar': buscar,
        'pagina': '$pagina',
        'porPagina': '$porPagina',
      },
    );
    return AppointmentPage.fromJson(asMap(data));
  }

  /// GET /api/appointments/:id, con la orden derivada (`null` si aún no
  /// existe).
  Future<Appointment> detail(int id) async {
    final dynamic data = await _api.get('/appointments/$id');
    return Appointment.fromJson(asMap(data));
  }

  /// POST /api/appointments. Todos los campos son obligatorios (FR-005) y el
  /// backend responde `409` si el vehículo ya tiene una cita a la misma fecha
  /// y hora; con `confirmar: true` se guarda pese al conflicto (FR-008).
  Future<Appointment> create({
    required int clienteId,
    required int vehiculoId,
    required String fecha,
    required String hora,
    required String motivo,
    bool confirmar = false,
  }) async {
    final dynamic data = await _api.post(
      '/appointments',
      body: <String, dynamic>{
        'clienteId': clienteId,
        'vehiculoId': vehiculoId,
        'fecha': fecha,
        'hora': hora,
        'motivo': motivo,
        if (confirmar) 'confirmar': true,
      },
    );
    return Appointment.fromJson(asMap(data));
  }

  /// PUT /api/appointments/:id. Solo citas `PROGRAMADA`; el cuerpo es el mismo
  /// que el alta (sin `confirmar`) y conserva cliente y vehículo.
  Future<Appointment> update({
    required int id,
    required int clienteId,
    required int vehiculoId,
    required String fecha,
    required String hora,
    required String motivo,
  }) async {
    final dynamic data = await _api.put(
      '/appointments/$id',
      body: <String, dynamic>{
        'clienteId': clienteId,
        'vehiculoId': vehiculoId,
        'fecha': fecha,
        'hora': hora,
        'motivo': motivo,
      },
    );
    return Appointment.fromJson(asMap(data));
  }

  /// POST /api/appointments/:id/cancelar. El motivo es opcional (FR-006).
  Future<Appointment> cancel({required int id, String motivo = ''}) async {
    final dynamic data = await _api.post(
      '/appointments/$id/cancelar',
      body: <String, dynamic>{
        if (motivo.isNotEmpty) 'motivo': motivo,
      },
    );
    return Appointment.fromJson(asMap(data));
  }

  /// POST /api/appointments/:id/recibir: pasa la cita a `RECIBIDA` sin crear
  /// ninguna orden y devuelve la precarga del formulario (FR-007).
  Future<ReceivedAppointment> receive({required int id}) async {
    final dynamic data = await _api.post('/appointments/$id/recibir');
    return ReceivedAppointment.fromJson(asMap(data));
  }
}
