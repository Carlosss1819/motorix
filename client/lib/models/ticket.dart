import '../utils/parsing.dart';

/// Datos del taller que encabezan el comprobante (FR-007).
class WorkshopInfo {
  const WorkshopInfo({
    this.nombre = '',
    this.direccion = '',
    this.telefono = '',
  });

  factory WorkshopInfo.fromJson(Map<String, dynamic> json) => WorkshopInfo(
        nombre: asString(json['nombre']),
        direccion: asString(json['direccion']),
        telefono: asString(json['telefono']),
      );

  final String nombre;
  final String direccion;
  final String telefono;
}

/// Cliente que aparece en el ticket (FR-007).
class TicketClient {
  const TicketClient({this.id, this.nombre = '', this.telefono = ''});

  factory TicketClient.fromJson(Map<String, dynamic> json) => TicketClient(
        id: asIntOrNull(json['id']),
        nombre: asString(json['nombre']),
        telefono: asString(json['telefono']),
      );

  final int? id;
  final String nombre;
  final String telefono;
}

/// Vehículo del comprobante, con sus campos separados y el kilometraje
/// registrado en la entrada (FR-007).
class TicketVehicle {
  const TicketVehicle({
    this.id,
    this.marca = '',
    this.modelo = '',
    this.anio,
    this.placas = '',
    this.kilometraje = 0,
  });

  factory TicketVehicle.fromJson(Map<String, dynamic> json) => TicketVehicle(
        id: asIntOrNull(json['id']),
        marca: asString(json['marca']),
        modelo: asString(json['modelo']),
        anio: asIntOrNull(json['anio']),
        placas: asString(json['placas']),
        kilometraje: asInt(json['kilometraje']),
      );

  final int? id;
  final String marca;
  final String modelo;
  final int? anio;
  final String placas;
  final int kilometraje;

  /// Etiqueta legible «marca modelo año» para mostrar en una sola línea.
  String get etiqueta {
    final String base = <String>[marca, modelo].where((String parte) => parte.isNotEmpty).join(' ');
    if (anio == null || base.isEmpty) return base.isEmpty ? '—' : base;
    return '$base $anio';
  }
}

/// Línea de refacción anidada en un servicio del ticket (FR-007).
class TicketPartLine {
  const TicketPartLine({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.codigo,
    this.aviso,
  });

  factory TicketPartLine.fromJson(Map<String, dynamic> json) => TicketPartLine(
        codigo: asStringOrNull(json['codigo']),
        nombre: asString(json['nombre']),
        cantidad: asInt(json['cantidad']),
        precioUnitario: asNum(json['precioUnitario']),
        subtotal: asNum(json['subtotal']),
        aviso: asStringOrNull(json['aviso']),
      );

  /// «sin precio registrado» cuando la línea no tiene precio (FR-018).
  final String? aviso;

  final String? codigo;
  final String nombre;
  final int cantidad;
  final num precioUnitario;
  final num subtotal;
}

/// Servicio (mano de obra) del comprobante con sus refacciones (FR-007).
class TicketServiceLine {
  const TicketServiceLine({
    required this.descripcion,
    required this.manoDeObra,
    this.refacciones = const <TicketPartLine>[],
    this.avisoManoDeObra,
  });

  factory TicketServiceLine.fromJson(Map<String, dynamic> json) =>
      TicketServiceLine(
        descripcion: asString(json['descripcion']),
        manoDeObra: asNum(json['manoDeObra']),
        avisoManoDeObra: asStringOrNull(json['avisoManoDeObra']),
        refacciones: asList(json['refacciones'])
            .map(TicketPartLine.fromJson)
            .toList(),
      );

  final String descripcion;
  final num manoDeObra;
  final List<TicketPartLine> refacciones;

  /// «sin precio registrado» cuando la mano de obra no tiene precio (FR-018).
  final String? avisoManoDeObra;
}

/// Ticket de servicio (HU4, FR-007; contrato: contracts/tickets.md).
///
/// Sprint 5 (FR-019): se lee de la copia guardada al emitirse, con su versión
/// de formato; no hay archivos PDF ni datos de tarjeta (RN-14).
class Ticket {
  const Ticket({
    required this.id,
    required this.folio,
    required this.ordenId,
    required this.pagoId,
    required this.emitidoPor,
    required this.emitidoEn,
    required this.taller,
    required this.cliente,
    required this.vehiculo,
    required this.servicios,
    required this.subtotalManoDeObra,
    required this.subtotalRefacciones,
    required this.total,
    required this.metodoPago,
    required this.estadoPago,
    required this.fecha,
    this.formatoVersion,
    this.formatoAnterior = false,
    this.desgloseNoCoincide = false,
    this.nota,
    this.pagoAnulado = false,
    this.vigente = true,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: asInt(json['id']),
        folio: asString(json['folio']),
        ordenId: asInt(json['ordenId']),
        pagoId: asInt(json['pagoId']),
        emitidoPor: asString(json['emitidoPor']),
        emitidoEn: asString(json['emitidoEn']),
        taller: WorkshopInfo.fromJson(asMap(json['taller'])),
        cliente: TicketClient.fromJson(asMap(json['cliente'])),
        vehiculo: TicketVehicle.fromJson(asMap(json['vehiculo'])),
        servicios: asList(json['servicios'])
            .map(TicketServiceLine.fromJson)
            .toList(),
        subtotalManoDeObra: asNum(json['subtotalManoDeObra']),
        subtotalRefacciones: asNum(json['subtotalRefacciones']),
        total: asNum(json['total']),
        metodoPago: asString(json['metodoPago']),
        estadoPago: asString(json['estadoPago']),
        fecha: asString(json['fecha']),
        formatoVersion: asIntOrNull(json['formatoVersion']),
        formatoAnterior: asBool(json['formatoAnterior']),
        desgloseNoCoincide: asBool(json['desgloseNoCoincide']),
        nota: asStringOrNull(json['nota']),
        pagoAnulado: asBool(json['pagoAnulado']),
        vigente: asBool(json['vigente'], true),
      );

  final int id;
  final String folio;
  final int ordenId;
  final int pagoId;
  final String emitidoPor;
  final String emitidoEn;
  final WorkshopInfo taller;
  final TicketClient cliente;
  final TicketVehicle vehiculo;
  final List<TicketServiceLine> servicios;
  final num subtotalManoDeObra;
  final num subtotalRefacciones;
  final num total;
  final String metodoPago;
  final String estadoPago;
  final String fecha;

  /// Sprint 5 (FR-019, FR-020, FR-022): versión de la copia (1 = formato
  /// anterior, 2 = Sprint 5), nota cuando el desglose no coincide con lo
  /// cobrado y marcas calculadas al consultar.
  final int? formatoVersion;
  final bool formatoAnterior;
  final bool desgloseNoCoincide;
  final String? nota;
  final bool pagoAnulado;
  final bool vigente;
}

/// Resumen de un ticket de la orden (Sprint 5, FR-033): folio, fecha y marcas.
class TicketSummary {
  const TicketSummary({
    required this.id,
    required this.folio,
    required this.pagoId,
    required this.emitidoEn,
    this.vigente = false,
    this.pagoAnulado = false,
    this.formatoAnterior = false,
  });

  factory TicketSummary.fromJson(Map<String, dynamic> json) => TicketSummary(
        id: asInt(json['id']),
        folio: asString(json['folio']),
        pagoId: asInt(json['pagoId']),
        emitidoEn: asString(json['emitidoEn']),
        vigente: asBool(json['vigente']),
        pagoAnulado: asBool(json['pagoAnulado']),
        formatoAnterior: asBool(json['formatoAnterior']),
      );

  final int id;
  final String folio;
  final int pagoId;
  final String emitidoEn;
  final bool vigente;
  final bool pagoAnulado;
  final bool formatoAnterior;
}

/// Resultado de `GET /api/tickets/orden/:ordenId`: si la orden tiene ticket
/// vigente, el comprobante vigente y (Sprint 5) todos los tickets de la orden,
/// del más reciente al más antiguo.
class TicketLookup {
  const TicketLookup({
    required this.existe,
    this.ticket,
    this.tickets = const <TicketSummary>[],
  });

  final bool existe;
  final Ticket? ticket;
  final List<TicketSummary> tickets;

  /// Tickets que no son el vigente (por ejemplo, de pagos anulados).
  List<TicketSummary> get anteriores =>
      tickets.where((TicketSummary t) => !t.vigente).toList();
}
