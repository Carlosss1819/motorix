import 'package:flutter/foundation.dart';

import '../utils/app_theme.dart';

/// Búsquedas del header para cada sección con lista.
abstract final class SearchHints {
  static const String clients = 'Buscar por nombre, teléfono o correo';
  static const String vehicles =
      'Buscar por placas, marca, modelo o propietario';
  static const String users = 'Buscar por usuario o correo';
  static const String orders = 'Buscar por placas o nombre del cliente';
}

/// Estado compartido del shell: ancho del sidebar y búsqueda del header.
///
/// El estado se conserva en memoria mientras la aplicación está abierta.
class ShellProvider extends ChangeNotifier {
  ShellProvider({double? initialWidth})
      : _expanded = (initialWidth ?? 0) >= AppMetrics.narrowBreakpoint;

  bool _expanded;

  /// Una búsqueda por sección, para que cada pantalla recupere la suya.
  final Map<String, String> _queries = <String, String>{};

  bool get expanded => _expanded;

  void toggle() {
    setExpanded(!_expanded);
  }

  void setExpanded(bool value) {
    if (_expanded == value) {
      return;
    }
    _expanded = value;
    notifyListeners();
  }

  /// Ancho efectivo del sidebar según el estado actual.
  double get width =>
      _expanded ? AppMetrics.sidebarExpandedWidth : AppMetrics.sidebarCollapsedWidth;

  String queryFor(String hint) => _queries[hint] ?? '';

  void setQuery(String hint, String value) {
    if (hint.isEmpty || _queries[hint] == value || (value.isEmpty && !_queries.containsKey(hint))) {
      return;
    }
    if (value.isEmpty) {
      _queries.remove(hint);
    } else {
      _queries[hint] = value;
    }
    notifyListeners();
  }
}
