// Prueba del cierre por inactividad en el cliente (Sprint 7, US10, CA-23):
// cuando el backend rechaza la sesión inactiva con 401, la app la cierra y
// avisa para regresar al inicio de sesión.
import 'package:flutter_test/flutter_test.dart';

import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/messages.dart';

import 'sprint7_test_helpers.dart';

void main() {
  test('test_el_limite_de_inactividad_del_cliente_es_de_30_minutos', () {
    expect(AuthProvider.inactivityTimeout, const Duration(minutes: 30));
  });

  test('test_un_401_por_sesion_inactiva_cierra_la_sesion_y_avisa', () async {
    final ApiSimulada api = ApiSimulada(<String, Manejador>{
      'POST /api/auth/login': (_) => loginRespuesta(rol: 'RECEPTIONIST'),
      'GET /api/clients': (_) => respuestaJson(<String, dynamic>{
            'error': <String, dynamic>{'mensaje': 'La sesión se cerró o expiró', 'codigo': 'SESION_INVALIDA'},
          }, 401),
    });
    final AuthProvider auth = AuthProvider(api: api.cliente);
    final List<String> avisos = <String>[];
    auth.onSessionClosed = avisos.add;
    await auth.login(identificador: 'recepcion', contrasena: 'Recepcion2026!');
    expect(auth.isAuthenticated, isTrue);

    await expectLater(api.cliente.get('/clients'), throwsA(isA<ApiException>()));

    expect(auth.isAuthenticated, isFalse);
    expect(auth.token, isNull);
    expect(avisos, <String>[AppMessages.sessionClosed]);
  });
}
