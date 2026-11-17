import 'package:flutter/foundation.dart';

import '../models/notification.dart';
import '../services/api_client.dart';
import '../services/notifications_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Estado de la campana y del panel de avisos (Sprint 6, US1 y US6).
///
/// El contador se pide al iniciar sesión y en cada cambio de sección
/// (FR-017); no hay temporizador. Si el contador falla, se queda en 0 sin
/// mostrar error (contrato de interfaz): la campana no bloquea la navegación.
class NotificationsProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  NotificationsProvider({required ApiClient api, NotificationsService? service})
      : _service = service ?? NotificationsService(api);

  final NotificationsService _service;

  LoadStatus _status = LoadStatus.idle;
  NotificationsSummary? _resumen;
  String? _error;
  int _noLeidos = 0;

  LoadStatus get status => _status;
  NotificationsSummary? get resumen => _resumen;
  String? get error => _error;

  /// Número de la insignia de la campana.
  int get noLeidos => _noLeidos;

  /// Actualiza solo el contador; un fallo deja 0 sin error visible.
  Future<void> refreshCount() async {
    try {
      _noLeidos = await _service.fetchCount();
    } catch (_) {
      _noLeidos = 0;
    }
    notifyListeners();
  }

  /// Carga el panel completo y actualiza el contador con `noLeidos`.
  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final NotificationsSummary resumen = await _service.fetchAll();
      _resumen = resumen;
      _noLeidos = resumen.noLeidos;
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Marca un aviso como leído (US6). El contador baja en 1 si el servidor lo
  /// acepta; si falla, no cambia nada y devuelve `false`.
  Future<bool> markRead(NotificationItem aviso) async {
    if (aviso.leido) {
      return true;
    }
    try {
      await _service.markRead(aviso.clave);
    } catch (_) {
      return false;
    }
    final NotificationsSummary? actual = _resumen;
    if (actual != null) {
      _resumen = actual.markedRead(aviso.clave);
      _noLeidos = _resumen!.noLeidos;
    } else if (_noLeidos > 0) {
      _noLeidos -= 1;
    }
    notifyListeners();
    return true;
  }

  /// Limpia el estado al cerrar la sesión.
  void limpiar() {
    _status = LoadStatus.idle;
    _resumen = null;
    _error = null;
    _noLeidos = 0;
    notifyListeners();
  }
}
