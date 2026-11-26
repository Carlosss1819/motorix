import '../utils/parsing.dart';

/// Tipo de servicio del catálogo con su intervalo (Sprint 7, US3; contrato:
/// specs/007-reportes-configuracion/contracts/service-types.md).
class ServiceType {
  const ServiceType({
    required this.id,
    required this.nombre,
    this.intervaloDias,
    this.intervaloKm,
    this.activo = true,
  });

  factory ServiceType.fromJson(Map<String, dynamic> json) => ServiceType(
        id: asInt(json['id']),
        nombre: asString(json['nombre']),
        intervaloDias: asIntOrNull(json['intervaloDias']),
        intervaloKm: asIntOrNull(json['intervaloKm']),
        activo: asBool(json['activo'], true),
      );

  final int id;
  final String nombre;
  final int? intervaloDias;
  final int? intervaloKm;
  final bool activo;

  /// Texto breve del intervalo, por ejemplo «180 días · 5,000 km».
  String get intervaloTexto {
    final List<String> partes = <String>[
      if (intervaloDias != null) '$intervaloDias días',
      if (intervaloKm != null) '${_miles(intervaloKm!)} km',
    ];
    return partes.join(' · ');
  }

  static String _miles(int value) {
    final String digits = value.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

/// Propuesta del próximo mantenimiento con el intervalo del tipo (FR-011).
/// Misma regla que `server/utils/next-service.js`: fecha = hoy + días y
/// kilometraje = kilometraje actual + km.
class NextServiceProposal {
  const NextServiceProposal({this.fecha, this.kilometraje});

  factory NextServiceProposal.from(
    ServiceType tipo, {
    required DateTime hoy,
    int? kilometrajeActual,
  }) {
    final DateTime base = DateTime.utc(hoy.year, hoy.month, hoy.day);
    final DateTime? fecha = tipo.intervaloDias == null
        ? null
        : base.add(Duration(days: tipo.intervaloDias!));
    return NextServiceProposal(
      fecha: fecha == null
          ? null
          : '${fecha.year.toString().padLeft(4, '0')}-'
              '${fecha.month.toString().padLeft(2, '0')}-'
              '${fecha.day.toString().padLeft(2, '0')}',
      kilometraje: tipo.intervaloKm == null || kilometrajeActual == null
          ? null
          : kilometrajeActual + tipo.intervaloKm!,
    );
  }

  final String? fecha;
  final int? kilometraje;
}
