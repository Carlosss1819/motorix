import '../utils/parsing.dart';

/// Refacción del catálogo de inventario (US5/HU5; contrato:
/// contracts/parts.md). Término canónico: «refacción» (clarificación 3).
class Part {
  const Part({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.marca,
    required this.stockActual,
    required this.stockMinimo,
    required this.stockBajo,
    required this.precioCompra,
    required this.precioVenta,
    required this.activa,
    this.advertencias = const <String>[],
    this.conPrecioCompra = true,
    this.conPrecioVenta = true,
  });

  /// Código de la advertencia de FR-004 (D-07): se guardó, pero el precio de
  /// venta es menor que el de compra.
  static const String precioVentaMenorACompra = 'PRECIO_VENTA_MENOR_A_COMPRA';

  factory Part.fromJson(Map<String, dynamic> json) => Part(
        id: asInt(json['id']),
        codigo: asString(json['codigo']),
        nombre: asString(json['nombre']),
        categoria: asString(json['categoria']),
        marca: asStringOrNull(json['marca']),
        stockActual: asInt(json['stockActual']),
        stockMinimo: asInt(json['stockMinimo']),
        // Calculado por el backend: stockActual <= stockMinimo && stockMinimo > 0
        // (FR-020); un stockMínimo de 0 nunca genera alerta (FR-021).
        stockBajo: asBool(json['stockBajo']),
        precioCompra: asNumOrNull(json['precioCompra']),
        precioVenta: asNumOrNull(json['precioVenta']),
        activa: asBool(json['activa'], true),
        advertencias: asList(json['advertencias'])
            .map((dynamic item) => asString(asMap(item)['codigo']))
            .toList(),
        // Sprint 5 (R-10): el servidor omite la clave si el rol no la ve.
        conPrecioCompra: json.containsKey('precioCompra'),
        conPrecioVenta: json.containsKey('precioVenta'),
      );

  final int id;
  final String codigo;
  final String nombre;
  final String categoria;
  final String? marca;
  final int stockActual;
  final int stockMinimo;

  /// true cuando el stock llegó al mínimo y el mínimo es mayor que cero.
  final bool stockBajo;

  /// DECIMAL del backend: puede venir como texto (por ejemplo `"180.00"`).
  /// Sprint 5 (FR-024, FR-025): el servidor omite el campo cuando el rol no
  /// puede verlo, así que también es `null` en ese caso.
  final num? precioCompra;
  final num? precioVenta;

  /// La baja es solo de catálogo (FR-019): su historial persiste.
  final bool activa;

  /// Códigos de advertencia de la respuesta de alta o edición (FR-004).
  final List<String> advertencias;

  bool get ventaMenorACompra => advertencias.contains(precioVentaMenorACompra);

  /// `true` si la respuesta trajo la clave (aunque su valor sea null).
  final bool conPrecioCompra;
  final bool conPrecioVenta;
}

/// Precios de refacción visibles por rol (Sprint 5, FR-024, FR-025):
/// compra solo ADMIN; venta ADMIN y RECEPTIONIST; ninguno al mecánico.
abstract final class PartPriceVisibility {
  static bool compra(String? rol) => rol == 'ADMIN';
  static bool venta(String? rol) => rol == 'ADMIN' || rol == 'RECEPTIONIST';
}

/// Página paginada del listado de refacciones (R-10).
class PartPage {
  const PartPage({
    required this.elementos,
    required this.pagina,
    required this.paginas,
    required this.total,
  });

  factory PartPage.fromJson(Map<String, dynamic> json) => PartPage(
        elementos: asList(json['elementos'])
            .map((dynamic item) => Part.fromJson(asMap(item)))
            .toList(),
        pagina: asInt(json['pagina'], 1),
        paginas: asInt(json['paginas'], 1),
        total: asInt(json['total']),
      );

  final List<Part> elementos;
  final int pagina;
  final int paginas;
  final int total;
}
