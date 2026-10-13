import '../utils/parsing.dart';

/// Estados de una cita de recepción (FR-005, FR-006), en el orden del flujo
/// de recepción.
const List<String> appointmentStatusValues = <String>[
  'PROGRAMADA',
  'RECIBIDA',
  'CANCELADA',
  'NO_PRESENTADA',
];

/// Orden derivada de una cita (FR-007): el enlace vive en
/// `service_orders.appointment_id` y puede ser `null`.
class AppointmentOrder {
  const AppointmentOrder({
    required this.id,
    required this.estado,
    this.fechaIngreso,
  });

  factory AppointmentOrder.fromJson(Map<String, dynamic> json) =>
      AppointmentOrder(
        id: asInt(json['id']),
        estado: asString(json['estado']),
        fechaIngreso: asStringOrNull(json['fechaIngreso']),
      );

  final int id;
  final String estado;
  final String? fechaIngreso;
}

/// Cita de recepción con los datos del cliente y del vehículo (HU2).
///
/// El listado trae los campos básicos más `ordenId`; el detalle agrega el
/// objeto `orden` (contrato: contracts/appointments.md).
class Appointment {
  const Appointment({
    required this.id,
    required this.clienteId,
    required this.cliente,
    required this.vehiculoId,
    required this.vehiculo,
    required this.placas,
    required this.fecha,
    required this.hora,
    required this.motivo,
    required this.estado,
    this.motivoCancelacion = '',
    this.ordenId,
    this.orden,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: asInt(json['id']),
        clienteId: asInt(json['clienteId']),
        cliente: asString(json['cliente']),
        vehiculoId: asInt(json['vehiculoId']),
        vehiculo: asString(json['vehiculo']),
        placas: asString(json['placas']),
        fecha: asString(json['fecha']),
        hora: asString(json['hora']),
        motivo: asString(json['motivo']),
        estado: asString(json['estado']),
        motivoCancelacion: asString(json['motivoCancelacion']),
        ordenId: asIntOrNull(json['ordenId']),
        orden: json['orden'] is Map<String, dynamic>
            ? AppointmentOrder.fromJson(asMap(json['orden']))
            : null,
      );

  final int id;
  final int clienteId;
  final String cliente;
  final int vehiculoId;

  /// Descripción del vehículo (marca, modelo y año).
  final String vehiculo;
  final String placas;

  /// Fecha `AAAA-MM-DD` y hora `HH:MM` de la cita.
  final String fecha;
  final String hora;
  final String motivo;
  final String estado;
  final String motivoCancelacion;
  final int? ordenId;

  /// Orden derivada; solo el detalle la incluye (FR-007).
  final AppointmentOrder? orden;

  /// Solo las citas `PROGRAMADA` admiten edición, cancelación o recepción
  /// (FR-006).
  bool get programada => estado == 'PROGRAMADA';

  bool get puedeEditarse => programada;
  bool get puedeCancelarse => programada;
  bool get puedeRecibirse => programada;
}

/// Respuesta de `POST /api/appointments/:id/recibir`: la cita actualizada y
/// la precarga para el formulario de orden (FR-007). Recibir no crea órdenes.
class ReceivedAppointment {
  const ReceivedAppointment({
    required this.citaId,
    required this.estado,
    required this.clienteId,
    required this.vehiculoId,
    required this.motivo,
    required this.citaOrigen,
  });

  factory ReceivedAppointment.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> cita = asMap(json['cita']);
    final Map<String, dynamic> precarga = asMap(json['precargaOrden']);
    return ReceivedAppointment(
      citaId: asInt(cita['id']),
      estado: asString(cita['estado']),
      clienteId: asInt(precarga['clienteId']),
      vehiculoId: asInt(precarga['vehiculoId']),
      motivo: asString(precarga['motivo']),
      citaOrigen: asInt(precarga['citaId']),
    );
  }

  final int citaId;
  final String estado;
  final int clienteId;
  final int vehiculoId;
  final String motivo;
  final int citaOrigen;
}

/// Página del listado: `elementos`, `pagina`, `paginas` y `total`.
class AppointmentPage {
  const AppointmentPage({
    required this.elementos,
    required this.pagina,
    required this.paginas,
    required this.total,
  });

  factory AppointmentPage.fromJson(Map<String, dynamic> json) =>
      AppointmentPage(
        elementos: asList(json['elementos'])
            .map(Appointment.fromJson)
            .toList(),
        pagina: asInt(json['pagina'], 1),
        paginas: asInt(json['paginas'], 1),
        total: asInt(json['total']),
      );

  final List<Appointment> elementos;
  final int pagina;
  final int paginas;
  final int total;
}
