/// Mensajes compartidos de la interfaz. Siempre en español y sin detalles
/// internos del sistema.
abstract final class AppMessages {
  static const String unexpectedError =
      'Ocurrió un error inesperado. Intenta de nuevo.';

  static const String connectionError =
      'No se pudo conectar con el servidor. Verifica que el servicio esté '
      'disponible e inténtalo de nuevo.';

  static const String sessionExpired =
      'Tu sesión expiró por 30 minutos de inactividad. Inicia sesión de nuevo.';

  static const String sessionClosed =
      'La sesión se cerró. Inicia sesión de nuevo.';

  static const String noPermission =
      'No tienes permisos para acceder a esta sección.';
}
