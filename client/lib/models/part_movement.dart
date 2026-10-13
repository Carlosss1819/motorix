import '../utils/parsing.dart';

/// Un movimiento del inventario de una refacción (US6/HU6; contrato:
/// contracts/parts.md, sección `GET /api/parts/:id/movements`). Cada fila
/// explica un cambio de stock con su tipo, cantidad, motivo, orden asociada,
/// stock resultante y quién lo registró (SC-007, FR-030).
class PartMovement {
  const PartMovement({
    required this.id,
    required this.tipo,
    required this.cantidad,
    required this.motivo,
    required this.ordenId,
    required this.stockAfter,
    required this.registradoPor,
    required this.fecha,
  });

  factory PartMovement.fromJson(Map<String, dynamic> json) => PartMovement(
        id: asInt(json['id']),
        tipo: asString(json['tipo']),
        cantidad: asInt(json['cantidad']),
        motivo: asStringOrNull(json['motivo']),
        ordenId: asIntOrNull(json['ordenId']),
        stockAfter: asInt(json['stockAfter']),
        registradoPor: asStringOrNull(json['registradoPor']),
        fecha: asStringOrNull(json['fecha']),
      );

  final int id;

  /// ENTRADA, SALIDA o AJUSTE.
  final String tipo;
  final int cantidad;

  /// Obligatorio en los AJUSTE (FR-029); opcional en el resto.
  final String? motivo;

  /// Orden que originó la salida o la reposición; `null` en los movimientos
  /// de catálogo (por ejemplo el stock inicial).
  final int? ordenId;

  /// Stock que quedó después de este movimiento: el último es el vigente.
  final int stockAfter;

  /// Usuario que registró el movimiento (`null` si vino de un dato sembrado).
  final String? registradoPor;

  /// Fecha y hora del registro (`YYYY-MM-DD HH:mm:ss`).
  final String? fecha;
}

/// Página paginada del historial de movimientos (patrón R-10).
class PartMovementPage {
  const PartMovementPage({
    required this.elementos,
    required this.pagina,
    required this.paginas,
    required this.total,
  });

  factory PartMovementPage.fromJson(Map<String, dynamic> json) =>
      PartMovementPage(
        elementos: asList(json['elementos'])
            .map((dynamic item) => PartMovement.fromJson(asMap(item)))
            .toList(),
        pagina: asInt(json['pagina'], 1),
        paginas: asInt(json['paginas'], 1),
        total: asInt(json['total']),
      );

  final List<PartMovement> elementos;
  final int pagina;
  final int paginas;
  final int total;
}
