import '../models/shop_settings.dart';
import '../utils/parsing.dart';
import 'api_client.dart';

/// Operaciones de `/api/settings` (Sprint 7). Solo ADMIN: el backend
/// responde 403 a los demás roles.
class SettingsService {
  SettingsService(this._api);

  final ApiClient _api;

  /// GET /api/settings
  Future<ShopSettings> get() async {
    final dynamic data = await _api.get('/settings');
    return ShopSettings.fromJson(asMap(data));
  }

  /// PUT /api/settings con todos los campos del formulario.
  Future<ShopSettings> save(ShopSettings settings) async {
    final dynamic data = await _api.put('/settings', body: settings.toJson());
    return ShopSettings.fromJson(asMap(data));
  }
}
