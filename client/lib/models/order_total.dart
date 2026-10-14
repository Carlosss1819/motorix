import '../utils/parsing.dart';

/// Línea de mano de obra del desglose del total (FR-015, D2).
class LaborBreakdownLine {
  const LaborBreakdownLine({
    this.id,
    this.descripcion,
    required this.precio,
    this.aviso,
  });

  factory LaborBreakdownLine.fromJson(Map<String, dynamic> json) =>
      LaborBreakdownLine(
        id: asIntOrNull(json['id']),
        descripcion: asStringOrNull(json['descripcion']),
        precio: asNum(json['precio']),
        aviso: asStringOrNull(json['aviso']),
      );

  final int? id;
  final String? descripcion;
  final num precio;

  /// `"sin precio registrado"` cuando la partida tiene precio `NULL` (D2.1).
  final String? aviso;
}

/// Línea de refacciones del desglose del total (FR-015, D2): subtotal =
/// precioUnitario × cantidad con el precio vigente del catálogo.
class PartBreakdownLine {
  const PartBreakdownLine({
    this.id,
    this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.aviso,
  });

  factory PartBreakdownLine.fromJson(Map<String, dynamic> json) =>
      PartBreakdownLine(
        id: asIntOrNull(json['id']),
        descripcion: asStringOrNull(json['descripcion']),
        cantidad: asInt(json['cantidad']),
        precioUnitario: asNum(json['precioUnitario']),
        subtotal: asNum(json['subtotal']),
        aviso: asStringOrNull(json['aviso']),
      );

  final int? id;
  final String? descripcion;
  final int cantidad;
  final num precioUnitario;
  final num subtotal;

  /// `"sin precio registrado"` para filas heredadas sin catálogo, valoradas
  /// en 0 (D2.1).
  final String? aviso;
}

/// Desglose del total de una orden (`GET /api/payments/orden/:ordenId/total`).
class OrderBreakdown {
  const OrderBreakdown({
    this.manoDeObra = const <LaborBreakdownLine>[],
    this.refacciones = const <PartBreakdownLine>[],
  });

  factory OrderBreakdown.fromJson(Map<String, dynamic> json) =>
      OrderBreakdown(
        manoDeObra: asList(json['manoDeObra'])
            .map(LaborBreakdownLine.fromJson)
            .toList(),
        refacciones: asList(json['refacciones'])
            .map(PartBreakdownLine.fromJson)
            .toList(),
      );

  final List<LaborBreakdownLine> manoDeObra;
  final List<PartBreakdownLine> refacciones;
}

/// Total vigente de una orden al momento de cobrar (FR-015, T062).
///
/// Lo calcula el backend con los mismos precios que exige para registrar el
/// pago, así el formulario precarga un monto que siempre coincide.
class OrderTotal {
  const OrderTotal({
    required this.ordenId,
    required this.subtotalManoDeObra,
    required this.subtotalRefacciones,
    required this.total,
    this.desglose = const OrderBreakdown(),
  });

  factory OrderTotal.fromJson(Map<String, dynamic> json) => OrderTotal(
        ordenId: asInt(json['ordenId']),
        subtotalManoDeObra: asNum(json['subtotalManoDeObra']),
        subtotalRefacciones: asNum(json['subtotalRefacciones']),
        total: asNum(json['total']),
        desglose: json['desglose'] is Map<String, dynamic>
            ? OrderBreakdown.fromJson(asMap(json['desglose']))
            : const OrderBreakdown(),
      );

  final int ordenId;
  final num subtotalManoDeObra;
  final num subtotalRefacciones;
  final num total;
  final OrderBreakdown desglose;
}
