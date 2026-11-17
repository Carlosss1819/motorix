import '../utils/parsing.dart';

/// Pantallas a las que lleva un aviso (contracts/notifications.md).
abstract final class NotificationScreens {
  static const String orden = 'ORDEN';
  static const String citas = 'CITAS';
  static const String vehiculo = 'VEHICULO';
  static const String refaccion = 'REFACCION';
}

/// Tipos de aviso del Sprint 6 (FR-001 a FR-006).
abstract final class NotificationTypes {
  static const String mantVencido = 'MANT_VENCIDO';
  static const String ordenDetenida = 'ORDEN_DETENIDA';
  static const String stockAgotado = 'STOCK_AGOTADO';
  static const String stockBajo = 'STOCK_BAJO';
  static const String citaHoy = 'CITA_HOY';
  static const String mantProximo = 'MANT_PROXIMO';
}

/// Destino de un aviso: la pantalla y el objeto que abre; `fecha` solo para
/// Citas (`AAAA-MM-DD`).
class NotificationTarget {
  const NotificationTarget({required this.pantalla, required this.id, this.fecha});

  factory NotificationTarget.fromJson(Map<String, dynamic> json) {
    return NotificationTarget(
      pantalla: asString(json['pantalla']),
      id: asInt(json['id']),
      fecha: asStringOrNull(json['fecha']),
    );
  }

  final String pantalla;
  final int id;
  final String? fecha;
}

/// Un aviso calculado por el servidor. No trae importes (FR-012).
class NotificationItem {
  const NotificationItem({
    required this.clave,
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.fechaReferencia,
    required this.leido,
    required this.destino,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      clave: asString(json['clave']),
      tipo: asString(json['tipo']),
      titulo: asString(json['titulo']),
      descripcion: asString(json['descripcion']),
      fechaReferencia: asString(json['fechaReferencia']),
      leido: asBool(json['leido']),
      destino: NotificationTarget.fromJson(asMap(json['destino'])),
    );
  }

  final String clave;
  final String tipo;
  final String titulo;
  final String descripcion;
  final String fechaReferencia;
  final bool leido;
  final NotificationTarget destino;

  NotificationItem copyWith({bool? leido}) {
    return NotificationItem(
      clave: clave,
      tipo: tipo,
      titulo: titulo,
      descripcion: descripcion,
      fechaReferencia: fechaReferencia,
      leido: leido ?? this.leido,
      destino: destino,
    );
  }
}

/// Grupo del panel (FR-007a): un tipo, su título, cantidad y avisos.
class NotificationGroup {
  const NotificationGroup({
    required this.tipo,
    required this.titulo,
    required this.cantidad,
    required this.noLeidos,
    required this.avisos,
  });

  factory NotificationGroup.fromJson(Map<String, dynamic> json) {
    return NotificationGroup(
      tipo: asString(json['tipo']),
      titulo: asString(json['titulo']),
      cantidad: asInt(json['cantidad']),
      noLeidos: asInt(json['noLeidos']),
      avisos: asList(json['avisos']).map(NotificationItem.fromJson).toList(),
    );
  }

  final String tipo;
  final String titulo;
  final int cantidad;
  final int noLeidos;
  final List<NotificationItem> avisos;
}

/// Respuesta de `GET /api/notifications`.
class NotificationsSummary {
  const NotificationsSummary({
    required this.noLeidos,
    required this.totalAvisos,
    required this.grupos,
  });

  factory NotificationsSummary.fromJson(Map<String, dynamic> json) {
    return NotificationsSummary(
      noLeidos: asInt(json['noLeidos']),
      totalAvisos: asInt(json['totalAvisos']),
      grupos: asList(json['grupos']).map(NotificationGroup.fromJson).toList(),
    );
  }

  final int noLeidos;
  final int totalAvisos;
  final List<NotificationGroup> grupos;

  /// Copia con el aviso [clave] marcado como leído (el contador baja en 1).
  NotificationsSummary markedRead(String clave) {
    final bool cambio = grupos.any(
      (NotificationGroup g) =>
          g.avisos.any((NotificationItem a) => a.clave == clave && !a.leido),
    );
    final List<NotificationGroup> nuevos = <NotificationGroup>[
      for (final NotificationGroup grupo in grupos)
        NotificationGroup(
          tipo: grupo.tipo,
          titulo: grupo.titulo,
          cantidad: grupo.cantidad,
          noLeidos: grupo.avisos
              .where((NotificationItem a) => !a.leido && a.clave != clave)
              .length,
          avisos: <NotificationItem>[
            for (final NotificationItem aviso in grupo.avisos)
              aviso.clave == clave ? aviso.copyWith(leido: true) : aviso,
          ],
        ),
    ];
    return NotificationsSummary(
      noLeidos: cambio ? noLeidos - 1 : noLeidos,
      totalAvisos: totalAvisos,
      grupos: nuevos,
    );
  }
}
