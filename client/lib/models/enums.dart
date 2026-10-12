/// Catálogos de valores que devuelve la API.
///
/// Contratos: `specs/001-base-clientes-vehiculos/contracts/users.md` y
/// `clients.md`.
abstract final class Rol {
  static const String admin = 'ADMIN';
  static const String receptionist = 'RECEPTIONIST';
  static const String mechanic = 'MECHANIC';

  static const List<String> values = <String>[admin, receptionist, mechanic];

  /// Etiqueta en español de un rol.
  static String label(String rol) {
    return switch (rol) {
      admin => 'Administrador',
      receptionist => 'Recepcionista',
      mechanic => 'Mecánico',
      _ => rol,
    };
  }
}

/// Estados de los registros del sistema. El backend puede responder tanto
/// `ACTIVO`/`INACTIVO` como `ACTIVE`/`INACTIVE`, así que se aceptan ambos.
abstract final class Estado {
  static const String activo = 'ACTIVO';
  static const String inactivo = 'INACTIVO';

  static bool isActive(String? estado) =>
      estado == null || estado == 'ACTIVO' || estado == 'ACTIVE';

  static String label(String? estado) => isActive(estado) ? 'Activo' : 'Inactivo';
}
