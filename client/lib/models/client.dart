import '../utils/parsing.dart';
import 'enums.dart';
import 'vehicle.dart';

/// Cliente (propietario) registrado en el taller (contrato: contracts/clients.md).
class Client {
  const Client({
    required this.id,
    required this.nombre,
    required this.telefono,
    this.email,
    this.estado,
    this.fechaRegistro,
    this.vehiculos = const <VehicleSummary>[],
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: asInt(json['id']),
        nombre: asString(json['nombre']),
        telefono: asString(json['telefono']),
        email: asStringOrNull(json['email']),
        estado: asStringOrNull(json['estado']),
        fechaRegistro: asStringOrNull(json['fechaRegistro']),
        vehiculos: asList(json['vehiculos'])
            .map(VehicleSummary.fromJson)
            .toList(),
      );

  final int id;
  final String nombre;
  final String telefono;

  /// Correo electrónico: opcional.
  final String? email;

  final String? estado;
  final String? fechaRegistro;

  /// Solo se llena en el detalle del cliente (GET /api/clients/:id).
  final List<VehicleSummary> vehiculos;

  bool get isActive => Estado.isActive(estado);
  String get estadoLabel => Estado.label(estado);
}
