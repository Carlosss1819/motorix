import '../utils/formatters.dart';
import '../utils/parsing.dart';

/// Reportes disponibles (Sprint 7, Entrega B, US4 a US6). `ruta` es el
/// segmento de `/api/reports/<ruta>`.
enum ReportKind {
  ingresos('ingresos', 'Ingresos'),
  servicios('servicios', 'Servicios frecuentes'),
  productividad('productividad', 'Productividad'),
  refacciones('refacciones', 'Margen de refacciones'),
  rotacion('rotacion', 'Rotación');

  const ReportKind(this.ruta, this.titulo);

  final String ruta;
  final String titulo;
}

/// Rango de fechas `AAAA-MM-DD` de un reporte (FR-031).
class ReportRange {
  const ReportRange(this.desde, this.hasta);

  final String desde;
  final String hasta;

  /// Ciudad de México usa UTC-6 todo el año desde octubre de 2022 (sin
  /// horario de verano), así que la fecha local se obtiene restando 6 horas
  /// a la hora UTC, sin depender de la zona del equipo.
  static DateTime hoyCiudadDeMexico([DateTime? ahora]) {
    final DateTime utc = (ahora ?? DateTime.now()).toUtc();
    final DateTime local = utc.subtract(const Duration(hours: 6));
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Atajos «hoy», «semana» (lunes a hoy) y «mes» (día 1 a hoy).
  static ReportRange atajo(String atajo, [DateTime? ahora]) {
    final DateTime hoy = hoyCiudadDeMexico(ahora);
    final DateTime inicio = switch (atajo) {
      'semana' => hoy.subtract(Duration(days: hoy.weekday - DateTime.monday)),
      'mes' => DateTime.utc(hoy.year, hoy.month, 1),
      _ => hoy,
    };
    return ReportRange(_iso(inicio), _iso(hoy));
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Tabla de un reporte lista para mostrar.
class ReportTable {
  const ReportTable({this.titulo, required this.columnas, required this.filas});

  final String? titulo;
  final List<String> columnas;
  final List<List<String>> filas;
}

/// Reporte ya convertido a textos de pantalla: resumen y tablas.
class ReportView {
  const ReportView({required this.resumen, required this.tablas});

  final List<String> resumen;
  final List<ReportTable> tablas;

  bool get vacio => tablas.every((ReportTable t) => t.filas.isEmpty);

  static String _dinero(Object? valor) =>
      valor == null ? '—' : Formatters.money(asNum(valor));

  /// Convierte la respuesta JSON del backend (contracts/reports.md).
  factory ReportView.fromJson(ReportKind tipo, Map<String, dynamic> json) {
    final List<Map<String, dynamic>> elementos = asList(json['elementos']);
    switch (tipo) {
      case ReportKind.ingresos:
        return ReportView(
          resumen: <String>[
            'Total cobrado: ${_dinero(json['total'])} en ${asInt(json['pagos'])} pagos aprobados.',
          ],
          tablas: <ReportTable>[
            ReportTable(
              titulo: 'Por método',
              columnas: const <String>['Método', 'Pagos', 'Total'],
              filas: <List<String>>[
                for (final Map<String, dynamic> m in asList(json['porMetodo']))
                  <String>[asString(m['metodo']), '${asInt(m['pagos'])}', _dinero(m['total'])],
              ],
            ),
            ReportTable(
              titulo: 'Por día',
              columnas: const <String>['Fecha', 'Pagos', 'Total'],
              filas: <List<String>>[
                for (final Map<String, dynamic> d in asList(json['porDia']))
                  <String>[Formatters.date(asString(d['fecha'])), '${asInt(d['pagos'])}', _dinero(d['total'])],
              ],
            ),
          ],
        );
      case ReportKind.servicios:
        return ReportView(
          resumen: const <String>['Servicios de las órdenes terminadas en el periodo (máximo 50).'],
          tablas: <ReportTable>[
            ReportTable(
              columnas: const <String>['Servicio', 'Veces', 'Mano de obra'],
              filas: <List<String>>[
                for (final Map<String, dynamic> e in elementos)
                  <String>[
                    asStringOrNull(e['tipoServicio']) ?? '${asString(e['descripcion'])} (sin tipo)',
                    '${asInt(e['veces'])}',
                    _dinero(e['manoDeObra']),
                  ],
              ],
            ),
          ],
        );
      case ReportKind.productividad:
        return ReportView(
          resumen: const <String>['Órdenes que pasaron a terminado en el periodo, por mecánico asignado.'],
          tablas: <ReportTable>[
            ReportTable(
              columnas: const <String>['Mecánico', 'Órdenes terminadas', 'Mano de obra'],
              filas: <List<String>>[
                for (final Map<String, dynamic> e in elementos)
                  <String>[asString(e['mecanico']), '${asInt(e['ordenesTerminadas'])}', _dinero(e['manoDeObra'])],
              ],
            ),
          ],
        );
      case ReportKind.refacciones:
        final Map<String, dynamic> totales = asMap(json['totales']);
        return ReportView(
          resumen: <String>[
            'Totales (sin las líneas sin costo registrado): costo ${_dinero(totales['costo'])}, '
                'venta ${_dinero(totales['venta'])}, margen ${_dinero(totales['margen'])}.',
          ],
          tablas: <ReportTable>[
            ReportTable(
              columnas: const <String>['Código', 'Refacción', 'Cantidad', 'Costo', 'Venta', 'Margen'],
              filas: <List<String>>[
                for (final Map<String, dynamic> e in elementos)
                  <String>[
                    asString(e['codigo']),
                    asString(e['nombre']),
                    '${asInt(e['cantidad'])}',
                    e['costo'] == null ? 'Sin costo registrado' : _dinero(e['costo']),
                    _dinero(e['venta']),
                    _dinero(e['margen']),
                  ],
              ],
            ),
          ],
        );
      case ReportKind.rotacion:
        return ReportView(
          resumen: const <String>['Rotación = unidades que salieron en el periodo / existencia actual.'],
          tablas: <ReportTable>[
            ReportTable(
              columnas: const <String>['Código', 'Refacción', 'Salidas', 'Existencia', 'Rotación'],
              filas: <List<String>>[
                for (final Map<String, dynamic> e in elementos)
                  <String>[
                    asString(e['codigo']),
                    asString(e['nombre']),
                    '${asInt(e['salidas'])}',
                    '${asInt(e['existencia'])}',
                    e['rotacion'] == null ? 'Sin existencia' : asNum(e['rotacion']).toStringAsFixed(2),
                  ],
              ],
            ),
          ],
        );
    }
  }
}
