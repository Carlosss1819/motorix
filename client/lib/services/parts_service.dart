import '../models/part.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones del recurso `/api/parts` (US5/HU5; contrato:
/// contracts/parts.md). Escritura solo ADMIN (FR-022); lectura los tres roles.
class PartsService {
  PartsService(this._api);

  final ApiClient _api;

  /// GET /api/parts?buscar=&stockBajo=&activa=&pagina=&porPagina=
  ///
  /// `buscar` cubre nombre o código (FR-018); `stockBajo=true` filtra las
  /// alertas de existencias (FR-020, R-10).
  Future<PartPage> list({
    String buscar = '',
    bool stockBajo = false,
    bool? activa,
    int pagina = 1,
    int porPagina = 10,
  }) async {
    final dynamic data = await _api.get(
      '/parts',
      query: <String, String>{
        'buscar': buscar,
        if (stockBajo) 'stockBajo': 'true',
        if (activa != null) 'activa': activa ? 'true' : 'false',
        'pagina': '$pagina',
        'porPagina': '$porPagina',
      },
    );
    return PartPage.fromJson(asMap(data));
  }

  /// GET /api/parts/:id
  Future<Part> detail(int id) async {
    final dynamic data = await _api.get('/parts/$id');
    return Part.fromJson(asMap(data));
  }

  /// POST /api/parts. `codigo` único en todo el catálogo (FR-017): el backend
  /// responde `409 CODIGO_DUPLICADO`. Un `stockInicial` mayor que cero genera
  /// además su ENTRADA inicial (SC-007); el stock actual no se envía después.
  Future<Part> create({
    required String codigo,
    required String nombre,
    required String categoria,
    String? marca,
    int stockInicial = 0,
    int stockMinimo = 0,
    num? precioCompra,
    num? precioVenta,
  }) async {
    final dynamic data = await _api.post(
      '/parts',
      body: <String, Object?>{
        'codigo': codigo,
        'nombre': nombre,
        'categoria': categoria,
        'marca': marca,
        'stockInicial': stockInicial,
        'stockMinimo': stockMinimo,
        'precioCompra': precioCompra,
        'precioVenta': precioVenta,
      },
    );
    return Part.fromJson(asMap(data));
  }

  /// PUT /api/parts/:id. Edición parcial del catálogo: el código es
  /// identificador y el stock actual solo cambia por movimientos (FR-022), ni
  /// se envían.
  Future<Part> update({
    required int id,
    required String nombre,
    required String categoria,
    String? marca,
    required int stockMinimo,
    num? precioCompra,
    num? precioVenta,
  }) async {
    final dynamic data = await _api.put(
      '/parts/$id',
      body: <String, Object?>{
        'nombre': nombre,
        'categoria': categoria,
        'marca': marca,
        'stockMinimo': stockMinimo,
        'precioCompra': precioCompra,
        'precioVenta': precioVenta,
      },
    );
    return Part.fromJson(asMap(data));
  }

  /// POST /api/parts/:id/desactivar (FR-019): baja de catálogo sin borrado.
  Future<String> deactivate(int id) async {
    final dynamic data = await _api.post('/parts/$id/desactivar');
    return asString(asMap(data)['mensaje']);
  }
}
