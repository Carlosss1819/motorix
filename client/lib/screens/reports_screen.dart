import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/report.dart';
import '../services/api_client.dart';
import '../services/reports_service.dart';
import '../utils/app_theme.dart';
import '../utils/csv_download.dart' as csv;
import '../widgets/app_table.dart';
import '../widgets/common_views.dart';

/// Función que entrega el CSV al usuario (inyectable para las pruebas).
typedef CsvSaver = Future<void> Function(
  BuildContext context, {
  required String nombre,
  required String contenido,
});

/// Reportes del taller (Sprint 7, Entrega B, US4 a US7): rango libre con
/// atajos hoy, semana y mes en la hora de Ciudad de México (máximo un año),
/// una pestaña por reporte y exportación CSV con el mismo contenido.
/// Solo ADMIN (FR-038).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.service, this.saveCsv, this.ahora});

  /// Servicio inyectable para las pruebas.
  final ReportsService? service;

  /// Descarga inyectable para las pruebas (por defecto, la del navegador).
  final CsvSaver? saveCsv;

  /// Hora de referencia de los atajos (las pruebas la fijan).
  final DateTime? ahora;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportsService _service =
      widget.service ?? ReportsService(context.read<ApiClient>());

  final TextEditingController _desde = TextEditingController();
  final TextEditingController _hasta = TextEditingController();

  ReportKind _tipo = ReportKind.ingresos;
  ReportRange? _rango;
  ReportView? _vista;
  bool _loading = false;
  bool _exportando = false;
  String? _error;

  static final RegExp _fecha = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  @override
  void initState() {
    super.initState();
    _aplicarAtajo('mes');
  }

  @override
  void dispose() {
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  void _aplicarAtajo(String atajo) {
    final ReportRange rango = ReportRange.atajo(atajo, widget.ahora);
    _desde.text = rango.desde;
    _hasta.text = rango.hasta;
    _consultar();
  }

  ReportRange? _rangoCapturado() {
    final String desde = _desde.text.trim();
    final String hasta = _hasta.text.trim();
    if (!_fecha.hasMatch(desde) || !_fecha.hasMatch(hasta)) {
      setState(() => _error = 'Las fechas deben tener el formato AAAA-MM-DD.');
      return null;
    }
    if (desde.compareTo(hasta) > 0) {
      setState(() => _error = 'La fecha inicial no puede ser posterior a la final.');
      return null;
    }
    return ReportRange(desde, hasta);
  }

  Future<void> _consultar() async {
    final ReportRange? rango = _rangoCapturado();
    if (rango == null) return;
    final ReportKind tipo = _tipo;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ReportView vista = await _service.fetch(tipo, rango);
      if (!mounted || tipo != _tipo) return;
      setState(() {
        _rango = rango;
        _vista = vista;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _vista = null;
        _loading = false;
      });
    }
  }

  void _cambiarTipo(ReportKind tipo) {
    if (tipo == _tipo) return;
    setState(() {
      _tipo = tipo;
      _vista = null;
    });
    _consultar();
  }

  Future<void> _exportar() async {
    final ReportRange? rango = _rango;
    if (rango == null) return;
    setState(() {
      _exportando = true;
      _error = null;
    });
    try {
      final String contenido = await _service.exportCsv(_tipo, rango);
      if (!mounted) return;
      final CsvSaver guardar = widget.saveCsv ?? csv.descargarCsv;
      await guardar(
        context,
        nombre: ReportsService.fileName(_tipo, rango),
        contenido: contenido,
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ReportView? vista = _vista;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Reportes', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Rango de hasta un año, en la hora de Ciudad de México. Los importes '
              'coinciden al centavo con los pagos y las órdenes.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: AppMetrics.comboboxWidth,
                    child: TextField(
                      key: const Key('reporte-desde'),
                      controller: _desde,
                      decoration: const InputDecoration(labelText: 'Desde (AAAA-MM-DD)'),
                    ),
                  ),
                  SizedBox(
                    width: AppMetrics.comboboxWidth,
                    child: TextField(
                      key: const Key('reporte-hasta'),
                      controller: _hasta,
                      decoration: const InputDecoration(labelText: 'Hasta (AAAA-MM-DD)'),
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('reporte-consultar'),
                    onPressed: _loading ? null : _consultar,
                    icon: const Icon(LucideIcons.search, size: AppMetrics.iconSizeSmall),
                    label: const Text('Consultar'),
                  ),
                  OutlinedButton(
                    key: const Key('reporte-atajo-hoy'),
                    onPressed: () => _aplicarAtajo('hoy'),
                    child: const Text('Hoy'),
                  ),
                  OutlinedButton(
                    key: const Key('reporte-atajo-semana'),
                    onPressed: () => _aplicarAtajo('semana'),
                    child: const Text('Semana'),
                  ),
                  OutlinedButton(
                    key: const Key('reporte-atajo-mes'),
                    onPressed: () => _aplicarAtajo('mes'),
                    child: const Text('Mes'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            DefaultTabController(
              length: ReportKind.values.length,
              child: TabBar(
                key: const Key('reporte-pestanas'),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                onTap: (int i) => _cambiarTipo(ReportKind.values[i]),
                tabs: <Widget>[
                  for (final ReportKind tipo in ReportKind.values) Tab(text: tipo.titulo),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_error != null) ...<Widget>[
              FormErrorBanner(mensaje: _error!),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (_loading)
              const LoadingView()
            else if (vista != null) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final String linea in vista.resumen)
                          Text(linea, style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('reporte-exportar-csv'),
                    onPressed: _exportando ? null : _exportar,
                    icon: const Icon(LucideIcons.download, size: AppMetrics.iconSizeSmall),
                    label: const Text('Exportar CSV'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (vista.vacio)
                const EmptyView(mensaje: 'No hay datos en el periodo seleccionado.')
              else
                for (final ReportTable tabla in vista.tablas) ...<Widget>[
                  if (tabla.titulo != null) ...<Widget>[
                    Text(tabla.titulo!, style: textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  AppPanel(
                    padding: EdgeInsets.zero,
                    child: FullWidthTable(
                      columns: <DataColumn>[
                        for (final String c in tabla.columnas) fluidColumn(c),
                      ],
                      rows: <DataRow>[
                        for (final List<String> fila in tabla.filas)
                          DataRow(cells: <DataCell>[
                            for (final String celda in fila) DataCell(Text(celda)),
                          ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
            ],
          ],
        ),
      ),
    );
  }
}
