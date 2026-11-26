// Pruebas de la bitácora (Sprint 7, US10, FR-024): lista paginada de solo
// lectura con filtros que viajan al backend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:motorix_client/screens/audit_log_screen.dart';

import 'sprint7_test_helpers.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  ApiSimulada crearApi() => ApiSimulada(<String, Manejador>{
        'GET /api/audit-log': (_) => respuestaJson(<String, dynamic>{
              'elementos': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1, 'fecha': '2026-11-26 10:15:03', 'usuarioId': 1, 'usuario': 'admin',
                  'accion': 'PRECIO_REFACCION_CAMBIADO', 'entidad': 'part', 'entidadId': 9,
                  'detalle': 'Precio de venta: 150 → 180',
                },
                <String, dynamic>{
                  'id': 2, 'fecha': '2026-11-26 09:00:00', 'usuarioId': null, 'usuario': null,
                  'accion': 'LOGIN_FALLIDO', 'entidad': 'user', 'entidadId': null,
                  'detalle': 'Usuario inexistente: fantasma',
                },
              ],
              'pagina': 1, 'paginas': 1, 'total': 2,
              'acciones': <String>['LOGIN_FALLIDO', 'PRECIO_REFACCION_CAMBIADO'],
            }),
      });

  testWidgets('test_muestra_las_acciones_con_usuario_y_detalle', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: const AuditLogScreen(), api: api.cliente);

    expect(find.text('Bitácora'), findsOneWidget);
    expect(find.text('Cambio de precio de refacción'), findsOneWidget);
    expect(find.text('Precio de venta: 150 → 180'), findsOneWidget);
    expect(find.text('Sin sesión'), findsOneWidget);
    expect(find.text('2 registros'), findsOneWidget);
    // Solo lectura: no hay botones para editar ni borrar entradas.
    expect(find.byTooltip('Eliminar'), findsNothing);
  });

  testWidgets('test_los_filtros_viajan_como_parametros', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: const AuditLogScreen(), api: api.cliente);

    await tester.enterText(find.byKey(const Key('bitacora-desde')), '2026-11-01');
    await tester.enterText(find.byKey(const Key('bitacora-hasta')), '2026-11-30');
    await tester.enterText(find.byKey(const Key('bitacora-usuario')), '1');
    await tester.tap(find.byKey(const Key('bitacora-filtrar')));
    await tester.pump();
    await tester.pump();

    final Map<String, String> query = api.llamadas('GET', '/api/audit-log').last.query;
    expect(query, containsPair('desde', '2026-11-01'));
    expect(query, containsPair('hasta', '2026-11-30'));
    expect(query, containsPair('usuarioId', '1'));
  });

  testWidgets('test_una_fecha_con_formato_invalido_no_consulta', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: const AuditLogScreen(), api: api.cliente);
    final int antes = api.peticiones.length;

    await tester.enterText(find.byKey(const Key('bitacora-desde')), '26/11/2026');
    await tester.tap(find.byKey(const Key('bitacora-filtrar')));
    await tester.pump();

    expect(api.peticiones.length, antes);
    expect(find.text('Las fechas deben tener el formato AAAA-MM-DD.'), findsOneWidget);
  });
}
