import 'package:flutter/foundation.dart';

import '../models/client_notice.dart';
import '../services/api_client.dart';
import '../services/client_notices_service.dart';
import '../utils/messages.dart';
import 'load_status.dart';

/// Resultado de marcar un cliente como avisado.
class MarkNotifiedResult {
  const MarkNotifiedResult({required this.ok, this.mensaje});

  final bool ok;

  /// Mensaje del servidor cuando no se pudo registrar (409, 404 u otro).
  final String? mensaje;
}

/// Estado de la pantalla «Clientes por avisar» (Sprint 6, US7).
class ClientNoticesProvider extends ChangeNotifier {
  /// [service] permite sustituir el servicio en pruebas, sin tocar la red.
  ClientNoticesProvider({required ApiClient api, ClientNoticesService? service})
      : _service = service ?? ClientNoticesService(api);

  final ClientNoticesService _service;

  LoadStatus _status = LoadStatus.idle;
  List<ClientNotice> _items = const <ClientNotice>[];
  String? _error;

  LoadStatus get status => _status;
  List<ClientNotice> get items => _items;
  String? get error => _error;

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _items = await _service.fetchAll();
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

  /// Registra el aviso. Si sale bien, el renglón sale de la lista; si el
  /// servidor responde 409 `YA_AVISADO` o 404 `HECHO_NO_VIGENTE`, devuelve su
  /// mensaje y recarga la lista (contrato de interfaz).
  Future<MarkNotifiedResult> markNotified(ClientNotice aviso) async {
    try {
      await _service.markNotified(aviso.clave);
    } on ApiException catch (e) {
      await load();
      return MarkNotifiedResult(ok: false, mensaje: e.mensaje);
    } catch (_) {
      return const MarkNotifiedResult(ok: false, mensaje: AppMessages.unexpectedError);
    }
    _items = _items.where((ClientNotice i) => i.clave != aviso.clave).toList();
    notifyListeners();
    return const MarkNotifiedResult(ok: true);
  }
}
