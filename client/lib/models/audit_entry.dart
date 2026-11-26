import '../utils/parsing.dart';

/// Entrada de la bitácora de acciones sensibles (Sprint 7, US10; contrato:
/// specs/007-reportes-configuracion/contracts/audit-log.md).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.fecha,
    required this.accion,
    this.usuarioId,
    this.usuario,
    this.entidad,
    this.entidadId,
    this.detalle,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: asInt(json['id']),
        fecha: asString(json['fecha']),
        accion: asString(json['accion']),
        usuarioId: asIntOrNull(json['usuarioId']),
        usuario: asStringOrNull(json['usuario']),
        entidad: asStringOrNull(json['entidad']),
        entidadId: asIntOrNull(json['entidadId']),
        detalle: asStringOrNull(json['detalle']),
      );

  final int id;
  final String fecha;
  final String accion;
  final int? usuarioId;
  final String? usuario;
  final String? entidad;
  final int? entidadId;
  final String? detalle;

  /// Nombre de la acción en español para la tabla.
  static String label(String accion) => switch (accion) {
        'LOGIN_FALLIDO' => 'Inicio de sesión fallido',
        'CUENTA_BLOQUEADA' => 'Cuenta bloqueada',
        'USUARIO_CREADO' => 'Usuario creado',
        'USUARIO_ROL_CAMBIADO' => 'Cambio de rol',
        'USUARIO_ACTIVADO' => 'Usuario activado',
        'USUARIO_DESACTIVADO' => 'Usuario desactivado',
        'CONFIG_ACTUALIZADA' => 'Configuración actualizada',
        'TIPO_SERVICIO_CREADO' => 'Tipo de servicio creado',
        'TIPO_SERVICIO_EDITADO' => 'Tipo de servicio editado',
        'TIPO_SERVICIO_ACTIVADO' => 'Tipo de servicio activado',
        'TIPO_SERVICIO_DESACTIVADO' => 'Tipo de servicio desactivado',
        'PRECIO_REFACCION_CAMBIADO' => 'Cambio de precio de refacción',
        'PAGO_ANULADO' => 'Pago anulado',
        'PAGO_CANCELADO' => 'Pago cancelado',
        'TERMINOS_ACEPTADOS' => 'Términos aceptados',
        _ => accion,
      };
}
