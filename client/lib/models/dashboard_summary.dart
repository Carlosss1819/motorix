import '../utils/parsing.dart';
import 'service_order.dart';

/// Línea de cita destacada del panel (FR-011, contrato: contracts/dashboard.md).
class DashboardAppointmentLine {
  const DashboardAppointmentLine({
    this.id,
    this.fecha = '',
    this.hora = '',
    this.cliente = '',
    this.estado = '',
  });

  factory DashboardAppointmentLine.fromJson(Map<String, dynamic> json) =>
      DashboardAppointmentLine(
        id: asIntOrNull(json['id']),
        fecha: asString(json['fecha']),
        hora: asString(json['hora']),
        cliente: asString(json['cliente']),
        estado: asString(json['estado']),
      );

  final int? id;
  final String fecha;
  final String hora;
  final String cliente;
  final String estado;
}

/// Bloque de citas del panel: total de hoy y próximas (máximo 5, HU6).
class DashboardAppointmentsBlock {
  const DashboardAppointmentsBlock({
    this.hoy = 0,
    this.proximas = const <DashboardAppointmentLine>[],
  });

  factory DashboardAppointmentsBlock.fromJson(Map<String, dynamic> json) =>
      DashboardAppointmentsBlock(
        hoy: asInt(json['hoy']),
        proximas: asList(json['proximas'])
            .map(DashboardAppointmentLine.fromJson)
            .toList(),
      );

  final int hoy;
  final List<DashboardAppointmentLine> proximas;
}

/// Línea de mantenimiento (próximo o vencido) con el objetivo que disparó la
/// alerta: fecha o kilometraje (FR-011).
class DashboardMaintenanceLine {
  const DashboardMaintenanceLine({
    this.id,
    this.vehiculo = '',
    this.tipo = '',
    this.estado = '',
    this.objetivo = '',
  });

  factory DashboardMaintenanceLine.fromJson(Map<String, dynamic> json) =>
      DashboardMaintenanceLine(
        id: asIntOrNull(json['id']),
        vehiculo: asString(json['vehiculo']),
        tipo: asString(json['tipo']),
        estado: asString(json['estado']),
        objetivo: asString(json['objetivo']),
      );

  final int? id;
  final String vehiculo;
  final String tipo;
  final String estado;
  final String objetivo;
}

/// Bloque de mantenimientos del panel: próximos y vencidos (FR-011).
class DashboardMaintenancesBlock {
  const DashboardMaintenancesBlock({
    this.proximos = const <DashboardMaintenanceLine>[],
    this.vencidos = const <DashboardMaintenanceLine>[],
  });

  factory DashboardMaintenancesBlock.fromJson(Map<String, dynamic> json) =>
      DashboardMaintenancesBlock(
        proximos: asList(json['proximos'])
            .map(DashboardMaintenanceLine.fromJson)
            .toList(),
        vencidos: asList(json['vencidos'])
            .map(DashboardMaintenanceLine.fromJson)
            .toList(),
      );

  final List<DashboardMaintenanceLine> proximos;
  final List<DashboardMaintenanceLine> vencidos;
}

/// Línea de refacción con stock bajo (regla `stockActual <= stockMinimo &&
/// stockMinimo > 0`, FR-011).
class DashboardLowStockLine {
  const DashboardLowStockLine({
    this.id,
    this.codigo = '',
    this.nombre = '',
    this.stockActual = 0,
    this.stockMinimo = 0,
  });

  factory DashboardLowStockLine.fromJson(Map<String, dynamic> json) =>
      DashboardLowStockLine(
        id: asIntOrNull(json['id']),
        codigo: asString(json['codigo']),
        nombre: asString(json['nombre']),
        stockActual: asInt(json['stockActual']),
        stockMinimo: asInt(json['stockMinimo']),
      );

  final int? id;
  final String codigo;
  final String nombre;
  final int stockActual;
  final int stockMinimo;
}

/// Bloque de alertas de inventario del panel (FR-011).
class DashboardInventoryBlock {
  const DashboardInventoryBlock({
    this.stockBajo = 0,
    this.refacciones = const <DashboardLowStockLine>[],
  });

  factory DashboardInventoryBlock.fromJson(Map<String, dynamic> json) =>
      DashboardInventoryBlock(
        stockBajo: asInt(json['stockBajo']),
        refacciones: asList(json['refacciones'])
            .map(DashboardLowStockLine.fromJson)
            .toList(),
      );

  final int stockBajo;
  final List<DashboardLowStockLine> refacciones;
}

/// Bloque de órdenes del panel (FR-010, FR-011, D4): contadores reales sobre
/// `service_orders`, sin datos derivados (CA-6).
class DashboardOrdersBlock {
  const DashboardOrdersBlock({
    this.total = 0,
    this.abiertas = 0,
    this.entregadas = 0,
    this.porEstado = const <String, int>{},
  });

  factory DashboardOrdersBlock.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> estados = asMap(json['porEstado']);
    // Los seis estados siempre presentes, en 0 si el backend aún no los trae.
    return DashboardOrdersBlock(
      total: asInt(json['total']),
      abiertas: asInt(json['abiertas']),
      entregadas: asInt(json['entregadas']),
      porEstado: <String, int>{
        for (final String estado in orderStatusValues)
          estado: asInt(estados[estado]),
      },
    );
  }

  final int total;
  final int abiertas;
  final int entregadas;
  final Map<String, int> porEstado;

  /// Sin órdenes registradas: la pantalla muestra el estado vacío (HU6-4).
  bool get vacio => total == 0;
}

/// Resumen del panel de control (HU5/HU6; contrato: contracts/dashboard.md).
///
/// El `fromJson` es tolerante: los bloques operativos pueden venir ausentes o
/// con arreglos vacíos sin errores (HU6-4).
class DashboardSummary {
  const DashboardSummary({
    required this.fecha,
    required this.ordenes,
    this.citas = const DashboardAppointmentsBlock(),
    this.mantenimientos = const DashboardMaintenancesBlock(),
    this.alertasInventario = const DashboardInventoryBlock(),
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        fecha: asString(json['fecha']),
        ordenes: DashboardOrdersBlock.fromJson(asMap(json['ordenes'])),
        citas: DashboardAppointmentsBlock.fromJson(asMap(json['citas'])),
        mantenimientos: DashboardMaintenancesBlock.fromJson(
          asMap(json['mantenimientos']),
        ),
        alertasInventario: DashboardInventoryBlock.fromJson(
          asMap(json['alertasInventario']),
        ),
      );

  final String fecha;
  final DashboardOrdersBlock ordenes;
  final DashboardAppointmentsBlock citas;
  final DashboardMaintenancesBlock mantenimientos;
  final DashboardInventoryBlock alertasInventario;
}
