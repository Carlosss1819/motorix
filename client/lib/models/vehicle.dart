import '../utils/parsing.dart';

/// Vehículo registrado en el taller (contrato: contracts/vehicles.md).
class Vehicle {
  const Vehicle({
    required this.id,
    required this.clienteId,
    required this.dueno,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.placas,
    this.vin,
    required this.kilometrajeActual,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: asInt(json['id']),
        clienteId: asInt(json['clienteId']),
        dueno: asString(json['dueno']),
        marca: asString(json['marca']),
        modelo: asString(json['modelo']),
        anio: asInt(json['anio']),
        placas: asString(json['placas']),
        vin: asStringOrNull(json['vin']),
        kilometrajeActual: asInt(json['kilometrajeActual']),
      );

  final int id;
  final int clienteId;

  /// Nombre del propietario.
  final String dueno;
  final String marca;
  final String modelo;
  final int anio;
  final String placas;

  /// Opcional; único cuando existe.
  final String? vin;
  final int kilometrajeActual;

  String get descripcion => '$marca $modelo';
}

/// Resumen de un vehículo tal como lo devuelve el detalle de un cliente.
class VehicleSummary {
  const VehicleSummary({
    required this.id,
    required this.placas,
    required this.marca,
    required this.modelo,
    required this.anio,
  });

  factory VehicleSummary.fromJson(Map<String, dynamic> json) => VehicleSummary(
        id: asInt(json['id']),
        placas: asString(json['placas']),
        marca: asString(json['marca']),
        modelo: asString(json['modelo']),
        anio: asInt(json['anio']),
      );

  final int id;
  final String placas;
  final String marca;
  final String modelo;
  final int anio;

  String get descripcion => '$marca $modelo';
}
