import '../utils/parsing.dart';

/// Una entrada del historial del vehículo (US1): una orden terminada o
/// entregada con todo el detalle del servicio. Contrato: contracts/history.md.
class HistoryEntry {
  const HistoryEntry({
    required this.ordenId,
    required this.fechaServicio,
    required this.kilometraje,
    required this.estadoOrden,
    required this.observaciones,
    required this.diagnostico,
    required this.recomendaciones,
    required this.servicios,
    required this.refacciones,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        ordenId: asInt(json['ordenId']),
        fechaServicio: asString(json['fechaServicio']),
        kilometraje: asInt(json['kilometraje']),
        estadoOrden: asString(json['estadoOrden']),
        observaciones: asStringOrNull(json['observaciones']),
        diagnostico: asStringOrNull(json['diagnostico']),
        recomendaciones: asStringOrNull(json['recomendaciones']),
        servicios: asList(json['servicios']).map(asString).toList(),
        refacciones: asList(json['refacciones'])
            .map((dynamic item) => HistoryPart.fromJson(asMap(item)))
            .toList(),
      );

  /// Identificador de la orden de servicio que originó la entrada.
  final int ordenId;

  /// Fecha del ingreso al taller (`YYYY-MM-DD`).
  final String fechaServicio;

  /// Kilometraje registrado al ingresar.
  final int kilometraje;

  /// Estado final de la orden (TERMINADO o ENTREGADO).
  final String estadoOrden;

  /// Motivo de visita registrado (observaciones de la entrada).
  final String? observaciones;

  /// Diagnóstico del mecánico, si se registró.
  final String? diagnostico;

  /// Recomendaciones para la entrega, si se registraron.
  final String? recomendaciones;

  /// Descripciones de los servicios realizados.
  final List<String> servicios;

  /// Refacciones usadas en el servicio.
  final List<HistoryPart> refacciones;
}

/// Una refacción del historial; las filas heredadas del Sprint 2 pueden venir
/// sin `partId` ni `codigo` (R-06).
class HistoryPart {
  const HistoryPart({
    required this.partId,
    required this.codigo,
    required this.nombre,
    required this.cantidad,
  });

  factory HistoryPart.fromJson(Map<String, dynamic> json) => HistoryPart(
        partId: asIntOrNull(json['partId']),
        codigo: asStringOrNull(json['codigo']),
        nombre: asString(json['nombre']),
        cantidad: asInt(json['cantidad']),
      );

  final int? partId;
  final String? codigo;
  final String nombre;
  final int cantidad;
}

/// Página paginada del historial (patrón R-10).
class HistoryPage {
  const HistoryPage({
    required this.elementos,
    required this.pagina,
    required this.paginas,
    required this.total,
  });

  factory HistoryPage.fromJson(Map<String, dynamic> json) => HistoryPage(
        elementos: asList(json['elementos'])
            .map((dynamic item) => HistoryEntry.fromJson(asMap(item)))
            .toList(),
        pagina: asInt(json['pagina'], 1),
        paginas: asInt(json['paginas'], 1),
        total: asInt(json['total']),
      );

  final List<HistoryEntry> elementos;
  final int pagina;
  final int paginas;
  final int total;
}
