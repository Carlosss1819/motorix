import '../utils/parsing.dart';

/// Métodos de pago admitidos (FR-002; contrato: contracts/payments.md).
const List<String> paymentMethodValues = <String>[
  'EFECTIVO',
  'TARJETA',
  'TRANSFERENCIA',
  'MERCADO_PAGO',
];

/// Estados de un pago (D7): `PAGADO` es el que liquida la orden y respalda
/// su entrega (FR-014).
const List<String> paymentStatusValues = <String>[
  'PENDIENTE',
  'PAGADO',
  'RECHAZADO',
  'CANCELADO',
  'ANULADO',
];

/// Etiqueta legible de un método de pago (US2: Efectivo, Tarjeta,
/// Transferencia, Mercado Pago).
String paymentMethodLabel(String metodo) {
  switch (metodo) {
    case 'EFECTIVO':
      return 'Efectivo';
    case 'TARJETA':
      return 'Tarjeta';
    case 'TRANSFERENCIA':
      return 'Transferencia';
    case 'MERCADO_PAGO':
      return 'Mercado Pago';
    default:
      return metodo;
  }
}

/// Etiqueta en español del estado de un pago (D7).
String paymentStatusLabel(String estado) {
  switch (estado) {
    case 'PENDIENTE':
      return 'Pendiente';
    case 'PAGADO':
      return 'Pagado';
    case 'RECHAZADO':
      return 'Rechazado';
    case 'CANCELADO':
      return 'Cancelado';
    case 'ANULADO':
      return 'Anulado';
    default:
      return estado;
  }
}

/// Pago de una orden de servicio (HU1; contrato: contracts/payments.md).
///
/// Nunca incluye datos de tarjeta ni credenciales del proveedor (RN-14): los
/// campos `referenciaExterna`, `enlacePago` y `modoPasarela` son propios del
/// cobro digital con Mercado Pago (D1).
class Payment {
  const Payment({
    required this.id,
    required this.ordenId,
    required this.monto,
    required this.metodo,
    required this.estado,
    this.referenciaExterna,
    this.enlacePago,
    this.modoPasarela,
    this.motivoAnulacion,
    this.registradoPor = '',
    this.fecha = '',
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: asInt(json['id']),
        ordenId: asInt(json['ordenId']),
        // MySQL devuelve DECIMAL como texto (por ejemplo, `"450.00"`).
        monto: asNum(json['monto']),
        metodo: asString(json['metodo']),
        estado: asString(json['estado']),
        referenciaExterna: asStringOrNull(json['referenciaExterna']),
        enlacePago: asStringOrNull(json['enlacePago']),
        modoPasarela: asStringOrNull(json['modoPasarela']),
        motivoAnulacion: asStringOrNull(json['motivoAnulacion']),
        registradoPor: asString(json['registradoPor']),
        fecha: asString(json['fecha']),
      );

  final int id;
  final int ordenId;
  final num monto;
  final String metodo;
  final String estado;
  final String? referenciaExterna;
  final String? enlacePago;
  final String? modoPasarela;
  final String? motivoAnulacion;
  final String registradoPor;

  /// Fecha y hora del pago como `AAAA-MM-DD HH:MM:SS`.
  final String fecha;

  /// Solo el pago aprobado liquida la orden (FR-014) y es el único que la
  /// administración puede anular (FR-016).
  bool get estaPagado => estado == 'PAGADO';
}

/// Página del listado de pagos de una orden (formato estándar R-10).
class PaymentPage {
  const PaymentPage({
    required this.elementos,
    required this.pagina,
    required this.paginas,
    required this.total,
  });

  factory PaymentPage.fromJson(Map<String, dynamic> json) => PaymentPage(
        elementos: asList(json['elementos'])
            .map(Payment.fromJson)
            .toList(),
        pagina: asInt(json['pagina'], 1),
        paginas: asInt(json['paginas'], 1),
        total: asInt(json['total']),
      );

  final List<Payment> elementos;
  final int pagina;
  final int paginas;
  final int total;
}
