// Pruebas de la pantalla de reportes (Sprint 7, Entrega B, US4 a US7):
// atajos en hora de Ciudad de México, pestañas por reporte, avisos de
// «sin costo registrado» y «sin existencia», y exportación CSV con el mismo
// rango que la pantalla.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:motorix_client/models/report.dart';
import 'package:motorix_client/screens/reports_screen.dart';

import 'sprint7_test_helpers.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // 2026-11-26 03:00 UTC = 2026-11-25 21:00 en Ciudad de México (miércoles).
  final DateTime ahora = DateTime.utc(2026, 11, 26, 3);

  ApiSimulada crearApi() => ApiSimulada(<String, Manejador>{
        'GET /api/reports/ingresos': (PeticionRegistrada p) => p.query['formato'] == 'csv'
            ? http.Response.bytes(
                utf8.encode(
                  '\uFEFFseccion,clave,total,pagos\r\nTotal,${p.query['desde']} a ${p.query['hasta']},1640.65,4\r\n',
                ),
                200,
                headers: <String, String>{'content-type': 'text/csv; charset=utf-8'},
              )
            : respuestaJson(<String, dynamic>{
                'desde': p.query['desde'],
                'hasta': p.query['hasta'],
                'total': 1640.65,
                'pagos': 4,
                'porMetodo': <Map<String, dynamic>>[
                  <String, dynamic>{'metodo': 'EFECTIVO', 'total': 0.3, 'pagos': 2},
                  <String, dynamic>{'metodo': 'TARJETA', 'total': 1640.35, 'pagos': 2},
                ],
                'porDia': <Map<String, dynamic>>[
                  <String, dynamic>{'fecha': '2026-11-03', 'total': 1640.65, 'pagos': 4},
                ],
              }),
        'GET /api/reports/refacciones': (_) => respuestaJson(<String, dynamic>{
              'elementos': <Map<String, dynamic>>[
                <String, dynamic>{
                  'refaccionId': 1, 'codigo': 'BUJ-01', 'nombre': 'Bujías', 'cantidad': 4,
                  'costo': 241, 'venta': 410.3, 'margen': 169.3, 'aviso': null,
                },
                <String, dynamic>{
                  'refaccionId': 2, 'codigo': 'LIM-01', 'nombre': 'Limpiador', 'cantidad': 2,
                  'costo': null, 'venta': 100, 'margen': null, 'aviso': 'sin costo registrado',
                },
              ],
              'totales': <String, dynamic>{'costo': 241, 'venta': 410.3, 'margen': 169.3},
            }),
        'GET /api/reports/rotacion': (_) => respuestaJson(<String, dynamic>{
              'elementos': <Map<String, dynamic>>[
                <String, dynamic>{
                  'refaccionId': 2, 'codigo': 'LIM-01', 'nombre': 'Limpiador', 'salidas': 4,
                  'existencia': 0, 'rotacion': null, 'aviso': 'sin existencia',
                },
              ],
            }),
        'GET /api/reports/servicios': (_) => respuestaJson(<String, dynamic>{'elementos': <dynamic>[]}),
      });

  test('test_los_atajos_usan_la_fecha_de_ciudad_de_mexico', () {
    final ReportRange hoy = ReportRange.atajo('hoy', ahora);
    expect(hoy.desde, '2026-11-25');
    expect(hoy.hasta, '2026-11-25');
    final ReportRange semana = ReportRange.atajo('semana', ahora);
    expect(semana.desde, '2026-11-23');
    expect(semana.hasta, '2026-11-25');
    final ReportRange mes = ReportRange.atajo('mes', ahora);
    expect(mes.desde, '2026-11-01');
    expect(mes.hasta, '2026-11-25');
  });

  testWidgets('test_abre_con_el_mes_y_muestra_el_total_de_ingresos', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: ReportsScreen(ahora: ahora), api: api.cliente);

    final Map<String, String> query = api.llamadas('GET', '/api/reports/ingresos').first.query;
    expect(query, containsPair('desde', '2026-11-01'));
    expect(query, containsPair('hasta', '2026-11-25'));
    expect(find.textContaining(r'Total cobrado: $1,640.65 en 4 pagos'), findsOneWidget);
    expect(find.text('EFECTIVO'), findsOneWidget);
    expect(find.text(r'$0.30'), findsOneWidget);
  });

  testWidgets('test_el_atajo_hoy_consulta_un_solo_dia', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: ReportsScreen(ahora: ahora), api: api.cliente);

    await tester.tap(find.byKey(const Key('reporte-atajo-hoy')));
    await tester.pump();
    await tester.pump();
    final Map<String, String> query = api.llamadas('GET', '/api/reports/ingresos').last.query;
    expect(query, containsPair('desde', '2026-11-25'));
    expect(query, containsPair('hasta', '2026-11-25'));
  });

  testWidgets('test_margen_muestra_sin_costo_registrado_y_los_totales', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: ReportsScreen(ahora: ahora), api: api.cliente);

    await tester.tap(find.text('Margen de refacciones'));
    await tester.pumpAndSettle();
    expect(find.text('Sin costo registrado'), findsOneWidget);
    expect(find.textContaining(r'margen $169.30'), findsOneWidget);

    await tester.tap(find.text('Rotación'));
    await tester.pumpAndSettle();
    expect(find.text('Sin existencia'), findsOneWidget);
  });

  testWidgets('test_un_periodo_sin_datos_muestra_aviso_y_no_error', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: ReportsScreen(ahora: ahora), api: api.cliente);

    await tester.tap(find.text('Servicios frecuentes'));
    await tester.pumpAndSettle();
    expect(find.text('No hay datos en el periodo seleccionado.'), findsOneWidget);
  });

  testWidgets('test_una_fecha_invalida_no_consulta', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    await montarPantalla(tester, child: ReportsScreen(ahora: ahora), api: api.cliente);
    final int antes = api.peticiones.length;

    await tester.enterText(find.byKey(const Key('reporte-desde')), '01/11/2026');
    await tester.tap(find.byKey(const Key('reporte-consultar')));
    await tester.pump();
    expect(api.peticiones.length, antes);
    expect(find.text('Las fechas deben tener el formato AAAA-MM-DD.'), findsOneWidget);
  });

  testWidgets('test_exportar_csv_pide_el_mismo_rango_y_entrega_el_archivo', (WidgetTester tester) async {
    final ApiSimulada api = crearApi();
    (String, String)? guardado;
    String? nombre;
    String? contenido;
    await montarPantalla(
      tester,
      child: ReportsScreen(
        ahora: ahora,
        saveCsv: (BuildContext context, {required String nombre, required String contenido}) async {
          guardado = (nombre, contenido);
        },
      ),
      api: api.cliente,
    );
    expect(guardado, isNull);

    await tester.tap(find.byKey(const Key('reporte-exportar-csv')));
    await tester.pumpAndSettle();

    final Map<String, String> query =
        api.llamadas('GET', '/api/reports/ingresos').last.query;
    expect(query, containsPair('formato', 'csv'));
    expect(query, containsPair('desde', '2026-11-01'));
    expect(query, containsPair('hasta', '2026-11-25'));
    (nombre, contenido) = guardado!;
    expect(nombre, 'ingresos_2026-11-01_2026-11-25.csv');
    // utf8.decode quita el BOM inicial; la descarga web lo vuelve a poner
    // (csv_download_web.dart), as\u00ED que aqu\u00ED se revisa el contenido.
    expect(contenido.replaceFirst('\uFEFF', ''), startsWith('seccion,clave,total,pagos'));
    expect(contenido, contains('Total,2026-11-01 a 2026-11-25,1640.65,4'));
  });
}

