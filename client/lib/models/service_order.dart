import '../utils/parsing.dart';

/// Estados de una orden de servicio (FR-014), en el orden del flujo del
/// panel de recepción y del taller.
const List<String> orderStatusValues = <String>[
  'RECIBIDO',
  'DIAGNOSTICO',
  'EN_REPARACION',
  'ESPERANDO_REFACCION',
  'TERMINADO',
  'ENTREGADO',
];

/// Mano de obra ligada a un servicio de la orden (contrato:
/// contracts/service-orders.md).
class OrderLabor {
  const OrderLabor({
    required this.id,
    required this.duracionMinutos,
    required this.precio,
  });

  factory OrderLabor.fromJson(Map<String, dynamic> json) => OrderLabor(
        id: asInt(json['id']),
        duracionMinutos: asInt(json['duracionMinutos']),
        precio: asNum(json['precio']),
      );

  final int id;

  /// Duración en minutos de la mano de obra.
  final int duracionMinutos;

  /// Precio de la mano de obra; el backend lo entrega como texto decimal.
  final num precio;
}

/// Servicio facturable agregado a la orden (HU4).
class OrderServiceItem {
  const OrderServiceItem({
    required this.id,
    required this.descripcion,
    this.manoDeObra,
  });

  factory OrderServiceItem.fromJson(Map<String, dynamic> json) =>
      OrderServiceItem(
        id: asInt(json['id']),
        descripcion: asString(json['descripcion']),
        manoDeObra: json['manoDeObra'] is Map<String, dynamic>
            ? OrderLabor.fromJson(asMap(json['manoDeObra']))
            : null,
      );

  final int id;
  final String descripcion;
  final OrderLabor? manoDeObra;
}

/// Repuesto registrado junto a la orden (RN-06).
class OrderPart {
  const OrderPart({
    required this.id,
    required this.descripcion,
    required this.cantidad,
  });

  factory OrderPart.fromJson(Map<String, dynamic> json) => OrderPart(
        id: asInt(json['id']),
        descripcion: asString(json['descripcion']),
        cantidad: asInt(json['cantidad'], 1),
      );

  final int id;
  final String descripcion;
  final int cantidad;
}

/// Entrada del historial de estados (FR-015).
class OrderHistoryEntry {
  const OrderHistoryEntry({
    required this.de,
    required this.a,
    required this.usuario,
    required this.fecha,
  });

  factory OrderHistoryEntry.fromJson(Map<String, dynamic> json) =>
      OrderHistoryEntry(
        de: asStringOrNull(json['de']),
        a: asString(json['a']),
        usuario: asString(json['usuario']),
        fecha: asString(json['fecha']),
      );

  /// Estado anterior; `null` en el alta de la orden.
  final String? de;
  final String a;
  final String usuario;
  final String fecha;
}

/// Orden de servicio con los datos del cliente y del vehículo (HU1).
///
/// El listado trae los campos básicos y el detalle agrega teléfono, nota de
/// corrección de kilometraje, diagnóstico, recomendaciones, servicios,
/// repuestos e historial (contrato: contracts/service-orders.md).
class ServiceOrder {
  const ServiceOrder({
    required this.id,
    required this.clienteId,
    required this.cliente,
    this.telefono = '',
    required this.vehiculoId,
    required this.vehiculo,
    required this.placas,
    required this.estado,
    required this.motivoVisita,
    required this.fechaIngreso,
    required this.kilometrajeEntrada,
    this.notaCorreccionKilometraje = '',
    this.mecanicoId,
    this.mecanico,
    this.citaId,
    this.diagnostico,
    this.diagnosticoBorrador = false,
    this.recomendaciones,
    this.fechaEntrega,
    this.servicios = const <OrderServiceItem>[],
    this.repuestos = const <OrderPart>[],
    this.historial = const <OrderHistoryEntry>[],
  });

  factory ServiceOrder.fromJson(Map<String, dynamic> json) => ServiceOrder(
        id: asInt(json['id']),
        clienteId: asInt(json['clienteId']),
        cliente: asString(json['cliente']),
        telefono: asString(json['telefono']),
        vehiculoId: asInt(json['vehiculoId']),
        vehiculo: asString(json['vehiculo']),
        placas: asString(json['placas']),
        estado: asString(json['estado']),
        motivoVisita: asString(json['motivoVisita']),
        fechaIngreso: asString(json['fechaIngreso']),
        kilometrajeEntrada: asInt(json['kilometrajeEntrada']),
        notaCorreccionKilometraje: asString(json['notaCorreccionKilometraje']),
        mecanicoId: asIntOrNull(json['mecanicoId']),
        mecanico: asStringOrNull(json['mecanico']),
        citaId: asIntOrNull(json['citaId']),
        diagnostico: asStringOrNull(json['diagnostico']),
        diagnosticoBorrador: asBool(json['diagnosticoBorrador']),
        recomendaciones: asStringOrNull(json['recomendaciones']),
        fechaEntrega: asStringOrNull(json['fechaEntrega']),
        servicios: asList(json['servicios'])
            .map(OrderServiceItem.fromJson)
            .toList(),
        repuestos: asList(json['repuestos']).map(OrderPart.fromJson).toList(),
        historial: asList(json['historial'])
            .map(OrderHistoryEntry.fromJson)
            .toList(),
      );

  final int id;
  final int clienteId;

  /// Nombre del cliente dueño del vehículo.
  final String cliente;
  final String telefono;
  final int vehiculoId;

  /// Descripción del vehículo (marca, modelo y año).
  final String vehiculo;
  final String placas;
  final String estado;
  final String motivoVisita;
  final String fechaIngreso;
  final int kilometrajeEntrada;

  /// Motivo de una corrección de kilometraje hecha por ADMIN (R-08).
  final String notaCorreccionKilometraje;
  final int? mecanicoId;
  final String? mecanico;
  final int? citaId;
  final String? diagnostico;

  /// `true` mientras el diagnóstico siga sin guardarse definitivamente (FR-011).
  final bool diagnosticoBorrador;
  final String? recomendaciones;
  final String? fechaEntrega;
  final List<OrderServiceItem> servicios;
  final List<OrderPart> repuestos;
  final List<OrderHistoryEntry> historial;

  /// La orden se puede editar mientras no esté terminada ni entregada.
  bool get editable =>
      estado != 'TERMINADO' && estado != 'ENTREGADO';

  /// La orden sigue en el taller (lo que ve el panel de recepción).
  bool get abierta => estado != 'ENTREGADO';
}

/// Página del listado: `elementos`, `pagina`, `paginas` y `total`.
class ServiceOrderPage {
  const ServiceOrderPage({
    required this.elementos,
    required this.pagina,
    required this.paginas,
    required this.total,
  });

  factory ServiceOrderPage.fromJson(Map<String, dynamic> json) =>
      ServiceOrderPage(
        elementos: asList(json['elementos'])
            .map(ServiceOrder.fromJson)
            .toList(),
        pagina: asInt(json['pagina'], 1),
        paginas: asInt(json['paginas'], 1),
        total: asInt(json['total']),
      );

  final List<ServiceOrder> elementos;
  final int pagina;
  final int paginas;
  final int total;
}
