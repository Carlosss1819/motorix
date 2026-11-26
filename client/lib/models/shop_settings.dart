import '../utils/parsing.dart';

/// Configuración del taller (Sprint 7, US1/US2; contrato:
/// specs/007-reportes-configuracion/contracts/settings.md).
class ShopSettings {
  const ShopSettings({
    required this.nombre,
    required this.direccion,
    required this.telefono,
    required this.antelacionDias,
    required this.antelacionKm,
  });

  factory ShopSettings.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> taller = asMap(json['taller']);
    final Map<String, dynamic> mantenimiento = asMap(json['mantenimiento']);
    return ShopSettings(
      nombre: asString(taller['nombre']),
      direccion: asString(taller['direccion']),
      telefono: asString(taller['telefono']),
      antelacionDias: asInt(mantenimiento['antelacionDias'], 30),
      antelacionKm: asInt(mantenimiento['antelacionKm'], 500),
    );
  }

  final String nombre;
  final String direccion;
  final String telefono;

  /// Márgenes de «Próximo»: antelación por defecto de los mantenimientos
  /// nuevos (los existentes conservan la suya).
  final int antelacionDias;
  final int antelacionKm;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'nombreTaller': nombre,
        'direccionTaller': direccion,
        'telefonoTaller': telefono,
        'antelacionDias': antelacionDias,
        'antelacionKm': antelacionKm,
      };
}
