import '../utils/parsing.dart';
import 'enums.dart';

/// Usuario con sesión en el sistema (contrato: contracts/users.md).
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.rol,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: asInt(json['id']),
        username: asString(json['username']),
        email: asString(json['email']),
        rol: asString(json['rol']),
      );

  final int id;
  final String username;
  final String email;

  /// Rol en inglés, tal como lo devuelve la API.
  final String rol;

  bool get isAdmin => rol == Rol.admin;

  /// Clientes y vehículos están disponibles para administrador y recepción.
  bool get canManageClients => isAdmin || rol == Rol.receptionist;

  String get rolLabel => Rol.label(rol);
}
