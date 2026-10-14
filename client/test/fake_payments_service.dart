import 'package:motorix_client/models/order_total.dart';
import 'package:motorix_client/models/payment.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/payments_service.dart';

/// Servicio de pagos falso para pruebas (HU1): devuelve los pagos y el
/// total que se le asignen sin abrir ninguna conexión y deja a la vista las
/// llamadas recibidas.
class FakePaymentsService extends PaymentsService {
  FakePaymentsService({
    this.pagos = const <Payment>[],
    this.total,
    this.errorLista,
    this.errorTotal,
    this.errorRegistro,
    this.errorAnulacion,
  }) : super(ApiClient());

  /// Pagos "vivientes" de la orden; se actualizan al registrar o anular.
  List<Payment> pagos;

  /// Total y desglose que responde el formulario (T062).
  OrderTotal? total;

  /// Fallos opcionales que se lanzan como [ApiException] para probar
  /// mensajes de error en pantalla.
  ApiException? errorLista;
  ApiException? errorTotal;
  ApiException? errorRegistro;
  ApiException? errorAnulacion;

  /// Veces que se pidieron la lista y el total: permite comprobar recargas.
  int llamadasLista = 0;
  int llamadasTotal = 0;

  /// Último pago registrado y último anulado con su motivo.
  Payment? ultimoRegistrado;
  int? ultimoAnulado;
  String? ultimoMotivo;

  int _siguienteId = 100;

  @override
  Future<PaymentPage> listByOrder({
    required int ordenId,
    int pagina = 1,
    int porPagina = 10,
  }) async {
    llamadasLista += 1;
    final ApiException? fallo = errorLista;
    if (fallo != null) {
      throw fallo;
    }
    return PaymentPage(
      elementos: pagos,
      pagina: 1,
      paginas: 1,
      total: pagos.length,
    );
  }

  @override
  Future<OrderTotal> fetchOrderTotal(int ordenId) async {
    llamadasTotal += 1;
    final ApiException? fallo = errorTotal;
    if (fallo != null) {
      throw fallo;
    }
    return total ??
        OrderTotal(
          ordenId: ordenId,
          subtotalManoDeObra: 0,
          subtotalRefacciones: 0,
          total: 0,
        );
  }

  @override
  Future<Payment> register({
    required int ordenId,
    required num monto,
    required String metodo,
    String? fecha,
  }) async {
    final ApiException? fallo = errorRegistro;
    if (fallo != null) {
      throw fallo;
    }
    final Payment creado = Payment(
      id: _siguienteId++,
      ordenId: ordenId,
      monto: monto,
      metodo: metodo,
      estado: 'PAGADO',
      registradoPor: 'recepcion',
      fecha: fecha == null || fecha.isEmpty ? '2026-10-14 10:00:00' : fecha,
    );
    pagos = <Payment>[...pagos, creado];
    ultimoRegistrado = creado;
    return creado;
  }

  @override
  Future<Payment> annul({required int id, required String motivo}) async {
    final ApiException? fallo = errorAnulacion;
    if (fallo != null) {
      throw fallo;
    }
    final List<Payment> actualizados = <Payment>[
      for (final Payment pago in pagos)
        pago.id == id
            ? Payment(
                id: pago.id,
                ordenId: pago.ordenId,
                monto: pago.monto,
                metodo: pago.metodo,
                estado: 'ANULADO',
                referenciaExterna: pago.referenciaExterna,
                enlacePago: pago.enlacePago,
                modoPasarela: pago.modoPasarela,
                motivoAnulacion: motivo,
                registradoPor: pago.registradoPor,
                fecha: pago.fecha,
              )
            : pago,
    ];
    pagos = actualizados;
    ultimoAnulado = id;
    ultimoMotivo = motivo;
    return actualizados.firstWhere((Payment pago) => pago.id == id);
  }
}

/// Fábrica compacta de un pago para las pruebas.
Payment pagoDePrueba({
  required int id,
  num monto = 450,
  String metodo = 'EFECTIVO',
  String estado = 'PAGADO',
  String fecha = '2026-10-14 10:15:00',
  String? motivoAnulacion,
}) =>
    Payment(
      id: id,
      ordenId: 7,
      monto: monto,
      metodo: metodo,
      estado: estado,
      motivoAnulacion: motivoAnulacion,
      registradoPor: 'recepcion',
      fecha: fecha,
    );
