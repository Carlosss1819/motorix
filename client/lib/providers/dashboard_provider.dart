import 'package:flutter/foundation.dart';

import '../models/dashboard_summary.dart';
import '../services/api_client.dart';
import '../services/dashboard_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Estado del panel de control (Sprint 4, US5): carga al abrir la pantalla,
/// acción «Actualizar» y estados de carga/vacío/error con una sola petición
/// por actualización (D4, sin tiempo real).
class DashboardProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  DashboardProvider({required ApiClient api, DashboardService? service})
      : _service = service ?? DashboardService(api);

  final DashboardService _service;

  LoadStatus _status = LoadStatus.idle;
  DashboardSummary? _resumen;
  String? _error;
  int _cargas = 0;

  LoadStatus get status => _status;
  DashboardSummary? get resumen => _resumen;
  String? get error => _error;

  /// Veces que la pantalla pidió el resumen (para las pruebas).
  int get cargas => _cargas;

  /// Carga (o actualiza) el resumen del panel; un `403 PANEL_SOLO_ADMIN` o
  /// cualquier fallo se publica como [error] en español, listo para reintentar.
  Future<void> load({String? fecha}) async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _resumen = await _service.fetchSummary(fecha: fecha);
      _cargas += 1;
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

  /// Reinicia el estado al salir de la pantalla.
  void limpiar() {
    _status = LoadStatus.idle;
    _resumen = null;
    _error = null;
    notifyListeners();
  }
}
