import '../utils/parsing.dart';

/// Estados calculados del mantenimiento (R-04): el backend los deriva de la
/// fecha y el kilometraje objetivo con la antelación propia del registro.
const List<String> maintenanceStatusValues = <String>[
  'NORMAL',
  'PROXIMO',
  'VENCIDO',
];

String maintenanceStatusLabel(String estado) => switch (estado) {
      'NORMAL' => 'Normal',
      'PROXIMO' => 'Próximo',
      'VENCIDO' => 'Vencido',
      _ => estado,
    };

/// Mantenimiento preventivo de un vehículo (contrato: contracts/maintenance.md).
class Maintenance {
  const Maintenance({
    required this.id,
    required this.vehiculoId,
    required this.vehiculo,
    required this.placas,
    required this.cliente,
    required this.tipoServicio,
    required this.fechaUltimoServicio,
    required this.kilometrajeUltimoServicio,
    required this.fechaObjetivo,
    required this.kilometrajeObjetivo,
    required this.intervaloDias,
    required this.intervaloKm,
    required this.antelacionDias,
    required this.antelacionKm,
    required this.notas,
    required this.estado,
  });

  factory Maintenance.fromJson(Map<String, dynamic> json) => Maintenance(
        id: asInt(json['id']),
        vehiculoId: asInt(json['vehiculoId']),
        vehiculo: asString(json['vehiculo']),
        placas: asString(json['placas']),
        cliente: asStringOrNull(json['cliente']),
        tipoServicio: asString(json['tipoServicio']),
        fechaUltimoServicio: asStringOrNull(json['fechaUltimoServicio']),
        kilometrajeUltimoServicio: asIntOrNull(json['kilometrajeUltimoServicio']),
        fechaObjetivo: asStringOrNull(json['fechaObjetivo']),
        kilometrajeObjetivo: asIntOrNull(json['kilometrajeObjetivo']),
        intervaloDias: asIntOrNull(json['intervaloDias']),
        intervaloKm: asIntOrNull(json['intervaloKm']),
        antelacionDias: asInt(json['antelacionDias'], 30),
        antelacionKm: asInt(json['antelacionKm'], 500),
        notas: asStringOrNull(json['notas']),
        estado: asString(json['estado']),
      );

  final int id;
  final int vehiculoId;

  /// Descripción del vehículo (`marca modelo año`).
  final String vehiculo;
  final String placas;
  final String? cliente;
  final String tipoServicio;
  final String? fechaUltimoServicio;
  final int? kilometrajeUltimoServicio;
  final String? fechaObjetivo;
  final int? kilometrajeObjetivo;
  final int? intervaloDias;
  final int? intervaloKm;
  final int antelacionDias;
  final int antelacionKm;
  final String? notas;

  /// Estado calculado por el backend: NORMAL, PROXIMO o VENCIDO.
  final String estado;
}

/// Página paginada del listado de mantenimientos.
class MaintenancePage {
  const MaintenancePage({
    required this.elementos,
    required this.pagina,
    required this.paginas,
    required this.total,
  });

  factory MaintenancePage.fromJson(Map<String, dynamic> json) => MaintenancePage(
        elementos: asList(json['elementos'])
            .map((dynamic item) => Maintenance.fromJson(asMap(item)))
            .toList(),
        pagina: asInt(json['pagina'], 1),
        paginas: asInt(json['paginas'], 1),
        total: asInt(json['total']),
      );

  final List<Maintenance> elementos;
  final int pagina;
  final int paginas;
  final int total;
}
