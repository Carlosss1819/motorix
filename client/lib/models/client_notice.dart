import '../utils/parsing.dart';
import 'notification.dart';

/// Motivos de «Clientes por avisar» (Sprint 6, US7, contracts/client-notices.md).
abstract final class ClientNoticeReasons {
  static const String vehiculoListo = 'VEHICULO_LISTO';
  static const String citaManana = 'CITA_MANANA';
  static const String mantVencido = 'MANT_VENCIDO';
  static const String mantProximo = 'MANT_PROXIMO';
}

/// Un cliente por avisar: un renglón por hecho (orden, cita o mantenimiento).
/// No trae importes.
class ClientNotice {
  const ClientNotice({
    required this.clave,
    required this.motivo,
    required this.motivoTexto,
    required this.clienteId,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.vehiculoId,
    required this.vehiculoDescripcion,
    required this.vehiculoPlacas,
    required this.fecha,
    required this.destino,
  });

  factory ClientNotice.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> cliente = asMap(json['cliente']);
    final Map<String, dynamic> vehiculo = asMap(json['vehiculo']);
    return ClientNotice(
      clave: asString(json['clave']),
      motivo: asString(json['motivo']),
      motivoTexto: asString(json['motivoTexto']),
      clienteId: asInt(cliente['id']),
      clienteNombre: asString(cliente['nombre']),
      clienteTelefono: asString(cliente['telefono']),
      vehiculoId: asInt(vehiculo['id']),
      vehiculoDescripcion: asString(vehiculo['descripcion']),
      vehiculoPlacas: asString(vehiculo['placas']),
      fecha: asString(json['fecha']),
      destino: NotificationTarget.fromJson(asMap(json['destino'])),
    );
  }

  final String clave;
  final String motivo;
  final String motivoTexto;
  final int clienteId;
  final String clienteNombre;
  final String clienteTelefono;
  final int vehiculoId;
  final String vehiculoDescripcion;
  final String vehiculoPlacas;
  final String fecha;
  final NotificationTarget destino;
}
