import '../utils/parsing.dart';
import 'enums.dart';

/// Usuario registrado en el sistema, tal como lo lista `/api/users`.
class UserRecord {
  const UserRecord({
    required this.id,
    required this.username,
    required this.email,
    required this.rol,
    required this.estado,
  });

  factory UserRecord.fromJson(Map<String, dynamic> json) => UserRecord(
        id: asInt(json['id']),
        username: asString(json['username']),
        email: asString(json['email']),
        rol: asString(json['rol']),
        estado: asStringOrNull(json['estado']) ?? Estado.activo,
      );

  final int id;
  final String username;
  final String email;

  /// Rol en inglés: ADMIN / RECEPTIONIST / MECHANIC.
  final String rol;

  /// Estado: ACTIVO / INACTIVO (también se acepta ACTIVE / INACTIVE).
  final String estado;

  bool get isActive => Estado.isActive(estado);
  String get estadoLabel => Estado.label(estado);
  String get rolLabel => Rol.label(rol);

  UserRecord copyWith({String? rol, String? estado}) => UserRecord(
        id: id,
        username: username,
        email: email,
        rol: rol ?? this.rol,
        estado: estado ?? this.estado,
      );
}
