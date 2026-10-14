import 'package:flutter/foundation.dart';

import '../models/order_total.dart';
import '../models/payment.dart';
import '../services/api_client.dart';
import '../services/payments_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Estado de la lista de pagos de una orden, de su total vigente y de las
/// acciones de cobro (HU1, Sprint 4).
class PaymentsProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  PaymentsProvider({required ApiClient api, PaymentsService? service})
      : _service = service ?? PaymentsService(api);

  /// Pagos por página en el listado paginado del backend (R-10).
  static const int porPagina = 10;

  final PaymentsService _service;

  // Lista de los pagos de la orden actual (incluye anulados, RN-9).
  LoadStatus _status = LoadStatus.idle;
  List<Payment> _items = const <Payment>[];
  String? _error;
  int _pagina = 1;
  int _paginas = 1;
  int _total = 0;
  int? _ordenId;

  // Total vigente de la orden para el formulario y para el bloque de cobro.
  LoadStatus _totalStatus = LoadStatus.idle;
  OrderTotal? _totalOrden;
  String? _totalError;

  LoadStatus get status => _status;
  List<Payment> get items => _items;
  String? get error => _error;
  int get pagina => _pagina;
  int get paginas => _paginas;
  int get total => _total;
  int? get ordenId => _ordenId;

  LoadStatus get totalStatus => _totalStatus;
  OrderTotal? get totalOrden => _totalOrden;
  String? get totalError => _totalError;

  bool get isLoading => _status == LoadStatus.loading;

  /// La orden ya tiene un pago aprobado: está liquidada y no admite otro
  /// cobro (FR-004).
  bool get tienePagoAprobado => _items.any((Payment p) => p.estaPagado);

  /// Carga la primera página de los pagos de una orden.
  Future<void> load(int ordenId) async {
    _ordenId = ordenId;
    _pagina = 1;
    await _fetch();
  }

  /// Vuelve a cargar la página actual de la orden abierta.
  Future<void> reload() async {
    if (_ordenId == null) {
      return;
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final PaymentPage page = await _service.listByOrder(
        ordenId: _ordenId!,
        pagina: _pagina,
        porPagina: porPagina,
      );
      _items = page.elementos;
      _pagina = page.pagina;
      _paginas = page.paginas;
      _total = page.total;
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _items = const <Payment>[];
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _items = const <Payment>[];
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Cambia de página de los pagos de la orden.
  Future<void> goToPage(int value) async {
    if (_ordenId == null) {
      return;
    }
    final int destino = value.clamp(1, _paginas);
    if (destino == _pagina) {
      return;
    }
    _pagina = destino;
    await _fetch();
  }

  /// Carga el total y el desglose vigentes de una orden (T062).
  Future<void> loadTotal(int ordenId) async {
    _ordenId = ordenId;
    _totalStatus = LoadStatus.loading;
    _totalError = null;
    notifyListeners();

    try {
      _totalOrden = await _service.fetchOrderTotal(ordenId);
      _totalStatus = LoadStatus.ready;
    } on ApiException catch (e) {
      _totalOrden = null;
      _totalError = e.mensaje;
      _totalStatus = LoadStatus.error;
    } catch (_) {
      _totalOrden = null;
      _totalError = AppMessages.unexpectedError;
      _totalStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Registra el cobro de la orden y refresca su lista de pagos (FR-001).
  /// Lanza [ApiException] con el `409` del backend (`ORDEN_YA_LIQUIDADA`,
  /// `MONTO_NO_COINCIDE`, `ORDEN_NO_COBRABLE`…), que la pantalla muestra
  /// tal cual.
  Future<Payment> register({
    required int ordenId,
    required num monto,
    required String metodo,
    String? fecha,
  }) async {
    final Payment creado = await _service.register(
      ordenId: ordenId,
      monto: monto,
      metodo: metodo,
      fecha: fecha,
    );
    await reload();
    return creado;
  }

  /// Anula un pago por error de captura (solo ADMIN, FR-016) y refresca la
  /// lista: el pago sigue visible con estado `ANULADO` (RN-9).
  Future<Payment> annul({required int id, required String motivo}) async {
    final Payment anulado = await _service.annul(id: id, motivo: motivo);
    await reload();
    return anulado;
  }
}
