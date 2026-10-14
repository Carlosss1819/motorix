import '../models/order_total.dart';
import '../models/payment.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones del recurso `/api/payments` (HU1; contrato:
/// contracts/payments.md). Registro y consulta para ADMIN y RECEPTIONIST
/// (FR-003); la anulación es solo de administración y se exige además en el
/// backend (FR-016, RN-15).
class PaymentsService {
  PaymentsService(this._api);

  final ApiClient _api;

  /// GET /api/payments/orden/:ordenId?pagina=&porPagina=
  ///
  /// Lista los pagos de una orden, incluidos los anulados, que son
  /// historial (RN-9).
  Future<PaymentPage> listByOrder({
    required int ordenId,
    int pagina = 1,
    int porPagina = 10,
  }) async {
    final dynamic data = await _api.get(
      '/payments/orden/$ordenId',
      query: <String, String>{
        'pagina': '$pagina',
        'porPagina': '$porPagina',
      },
    );
    return PaymentPage.fromJson(asMap(data));
  }

  /// GET /api/payments/orden/:ordenId/total (T062)
  ///
  /// Total y desglose vigentes calculados en backend (FR-015): el monto que
  /// se precarga en el formulario sale de aquí, de la misma fuente que
  /// valida el registro del pago.
  Future<OrderTotal> fetchOrderTotal(int ordenId) async {
    final dynamic data = await _api.get('/payments/orden/$ordenId/total');
    return OrderTotal.fromJson(asMap(data));
  }

  /// POST /api/payments. El backend exige que `monto` coincida con el total
  /// vigente de la orden (FR-015) y que la orden esté `TERMINADO` sin pago
  /// aprobado (FR-004); los errores llegan como [ApiException] con su
  /// código (`409 ORDEN_YA_LIQUIDADA`, `409 MONTO_NO_COINCIDE`…).
  Future<Payment> register({
    required int ordenId,
    required num monto,
    required String metodo,
    String? fecha,
  }) async {
    final dynamic data = await _api.post(
      '/payments',
      body: <String, Object?>{
        'ordenId': ordenId,
        'monto': monto,
        'metodo': metodo,
        if (fecha != null && fecha.isNotEmpty) 'fecha': fecha,
      },
    );
    return Payment.fromJson(asMap(data));
  }

  /// POST /api/payments/:id/anular. El motivo es obligatorio (1–255,
  /// FR-016); el pago anulado se conserva en la lista como historial.
  Future<Payment> annul({required int id, required String motivo}) async {
    final dynamic data = await _api.post(
      '/payments/$id/anular',
      body: <String, Object?>{'motivo': motivo},
    );
    return Payment.fromJson(asMap(data));
  }
}
