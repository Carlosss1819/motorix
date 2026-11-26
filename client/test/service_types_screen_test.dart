// Pruebas del catálogo de tipos de servicio (Sprint 7, US3): lista con su
// intervalo, alta con al menos un intervalo y desactivación con confirmación.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:motorix_client/models/service_type.dart';
import 'package:motorix_client/screens/service_types_screen.dart';

import 'sprint7_test_helpers.dart';

Map<String, dynamic> _tipo(int id, String nombre, {int? dias, int? km, bool activo = true}) =>
    <String, dynamic>{'id': id, 'nombre': nombre, 'intervaloDias': dias, 'intervaloKm': km, 'activo': activo};

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  ApiSimulada crearApi() => ApiSimulada(<String, Manejador>{
        'GET /api/service-types': (_) => respuestaJson(<String, dynamic>{
              'elementos': <Map<String, dynamic>>[
                _tipo(1, 'Cambio de aceite', dias: 180, km: 5000),
                _tipo(2, 'Revisión de frenos', dias: 365, activo: false),
              ],
            }),
        'POST /api/service-types': (PeticionRegistrada p) =>
            respuestaJson(_tipo(3, p.cuerpo!['nombre'] as String, dias: 90), 201),
        'POST /api/service-types/1/desactivar': (_) =>
            respuestaJson(_tipo(1, 'Cambio de aceite', dias: 180, km: 5000, activo: false)),
      });

  testWidgets('test_lista_los_tipos_con_su_intervalo_incluidos_los_inactivos', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: const ServiceTypesScreen(), api: api.cliente);

    expect(find.text('Cambio de aceite'), findsOneWidget);
    expect(find.text('180 días · 5,000 km'), findsOneWidget);
    expect(find.text('Revisión de frenos'), findsOneWidget);
    expect(api.llamadas('GET', '/api/service-types').first.query['incluirInactivos'], 'true');
  });

  testWidgets('test_el_alta_exige_al_menos_un_intervalo_y_luego_guarda', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: const ServiceTypesScreen(), api: api.cliente);

    await tester.tap(find.byKey(const Key('tipo-nuevo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tipo-nombre')), 'Alineación');
    await tester.tap(find.byKey(const Key('tipo-guardar')));
    await tester.pump();
    expect(find.text('Indica al menos un intervalo: en días o en kilómetros.'), findsNWidgets(2));
    expect(api.llamadas('POST', '/api/service-types'), isEmpty);

    await tester.enterText(find.byKey(const Key('tipo-dias')), '90');
    await tester.tap(find.byKey(const Key('tipo-guardar')));
    await tester.pumpAndSettle();

    expect(api.llamadas('POST', '/api/service-types').single.cuerpo, <String, dynamic>{
      'nombre': 'Alineación',
      'intervaloDias': 90,
      'intervaloKm': null,
    });
    expect(find.text('Tipo de servicio creado.'), findsOneWidget);
  });

  testWidgets('test_desactivar_pide_confirmacion', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: const ServiceTypesScreen(), api: api.cliente);

    await tester.tap(find.byKey(const Key('tipo-estado-1')));
    await tester.pumpAndSettle();
    expect(find.text('Desactivar tipo de servicio'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(api.llamadas('POST', '/api/service-types/1/desactivar'), hasLength(1));
  });

  test('test_la_propuesta_suma_el_intervalo_a_hoy_y_al_kilometraje_actual', () {
    const ServiceType tipo = ServiceType(id: 1, nombre: 'Cambio de aceite', intervaloDias: 180, intervaloKm: 5000);
    final NextServiceProposal propuesta =
        NextServiceProposal.from(tipo, hoy: DateTime(2026, 11, 26), kilometrajeActual: 20000);
    expect(propuesta.fecha, '2027-05-25');
    expect(propuesta.kilometraje, 25000);

    const ServiceType soloDias = ServiceType(id: 2, nombre: 'Frenos', intervaloDias: 365);
    final NextServiceProposal sinKm = NextServiceProposal.from(soloDias, hoy: DateTime(2026, 11, 26), kilometrajeActual: 20000);
    expect(sinKm.kilometraje, isNull);
    expect(sinKm.fecha, '2027-11-26');
  });
}
