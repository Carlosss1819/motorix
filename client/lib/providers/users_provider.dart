import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/user_record.dart';
import '../services/api_client.dart';
import '../services/users_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Estado de la lista de usuarios y sus mutaciones (US2, solo ADMIN).
class UsersProvider extends ChangeNotifier {
  UsersProvider({required ApiClient api}) : _service = UsersService(api);

  final UsersService _service;

  LoadStatus _status = LoadStatus.idle;
  List<UserRecord> _items = const <UserRecord>[];
  String? _error;

  LoadStatus get status => _status;
  List<UserRecord> get items => _items;
  String? get error => _error;
  bool get isLoading => _status == LoadStatus.loading;

  /// Carga la lista de usuarios.
  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _items = await _service.list();
      _status = LoadStatus.ready;
    } on ApiException catch (e) {
      _items = const <UserRecord>[];
      _error = e.mensaje;
      _status = LoadStatus.error;
    } catch (_) {
      _items = const <UserRecord>[];
      _error = AppMessages.unexpectedError;
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> reload() => load();

  /// Crea un usuario con rol asignado (FR-010). El backend responde `409` si
  /// el usuario o el correo ya existen.
  Future<UserRecord> create(NewUser user) async {
    final UserRecord created = await _service.create(user);
    await reload();
    return created;
  }

  /// Cambia el rol de un usuario con efecto inmediato (FR-011).
  Future<UserRecord> changeRole(int id, String rol) async {
    final UserRecord updated = await _service.update(id, rol: rol);
    await reload();
    return updated;
  }

  /// Activa o desactiva una cuenta (FR-011). Al desactivar, el backend cierra
  /// de inmediato la sesión abierta de ese usuario.
  Future<UserRecord> setStatus(int id, {required bool activo}) async {
    final UserRecord updated = await _service.update(
      id,
      estado: activo ? Estado.activo : Estado.inactivo,
    );
    await reload();
    return updated;
  }
}
