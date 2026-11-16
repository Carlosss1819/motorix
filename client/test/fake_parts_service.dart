import 'package:motorix_client/models/part.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/parts_service.dart';

/// Catálogo falso de refacciones: devuelve la lista que se le asigne sin
/// abrir ninguna conexión (selector de la orden, US7).
class FakePartsService extends PartsService {
  FakePartsService({this.parts = const <Part>[]}) : super(ApiClient());

  /// Refacciones que "viven" en el catálogo falso.
  List<Part> parts;

  /// Veces que se pidió el catálogo: permite comprobar sus recargas (US7).
  int llamadasList = 0;

  /// Advertencias que devuelve el alta o la edición (Sprint 5, FR-004).
  List<String> advertenciasAlGuardar = const <String>[];

  /// Altas recibidas (precios incluidos) para las aserciones.
  final List<({num? precioCompra, num? precioVenta})> guardados =
      <({num? precioCompra, num? precioVenta})>[];

  Part _guardada({
    required int id,
    required String codigo,
    required String nombre,
    required String categoria,
    String? marca,
    num? precioCompra,
    num? precioVenta,
  }) {
    guardados.add((precioCompra: precioCompra, precioVenta: precioVenta));
    return Part(
      id: id,
      codigo: codigo,
      nombre: nombre,
      categoria: categoria,
      marca: marca,
      stockActual: 0,
      stockMinimo: 0,
      stockBajo: false,
      precioCompra: precioCompra,
      precioVenta: precioVenta,
      activa: true,
      advertencias: advertenciasAlGuardar,
    );
  }

  @override
  Future<Part> create({
    required String codigo,
    required String nombre,
    required String categoria,
    String? marca,
    int stockInicial = 0,
    int stockMinimo = 0,
    num? precioCompra,
    num? precioVenta,
  }) async =>
      _guardada(
        id: 990,
        codigo: codigo,
        nombre: nombre,
        categoria: categoria,
        marca: marca,
        precioCompra: precioCompra,
        precioVenta: precioVenta,
      );

  @override
  Future<Part> update({
    required int id,
    required String nombre,
    required String categoria,
    String? marca,
    required int stockMinimo,
    num? precioCompra,
    num? precioVenta,
  }) async =>
      _guardada(
        id: id,
        codigo: 'EDIT-$id',
        nombre: nombre,
        categoria: categoria,
        marca: marca,
        precioCompra: precioCompra,
        precioVenta: precioVenta,
      );

  @override
  Future<PartPage> list({
    String buscar = '',
    bool stockBajo = false,
    bool? activa,
    int pagina = 1,
    int porPagina = 10,
  }) async {
    llamadasList += 1;
    return PartPage(
      elementos: parts,
      pagina: 1,
      paginas: 1,
      total: parts.length,
    );
  }
}

/// Fábrica compacta de una refacción para las pruebas.
Part parteDePrueba({
  required int id,
  required String codigo,
  required String nombre,
  int stockActual = 6,
  int stockMinimo = 1,
  bool activa = true,
  num? precioCompra,
  num? precioVenta,
}) =>
    Part(
      id: id,
      codigo: codigo,
      nombre: nombre,
      categoria: 'Frenos',
      marca: null,
      stockActual: stockActual,
      stockMinimo: stockMinimo,
      // Mismo cálculo que hace el backend (FR-020).
      stockBajo: stockActual <= stockMinimo && stockMinimo > 0,
      precioCompra: precioCompra,
      precioVenta: precioVenta,
      activa: activa,
    );
