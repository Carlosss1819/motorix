import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/audit_entry.dart';
import '../models/terms.dart';
import '../services/api_client.dart';
import '../services/audit_service.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/app_table.dart';
import '../widgets/common_views.dart';
import 'terms_screen.dart' show PagerBar;

/// Bitácora de acciones sensibles (Sprint 7, US10, FR-024): solo ADMIN, solo
/// lectura, paginada y con filtros de fecha, usuario y acción.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, this.service});

  /// Servicio inyectable para las pruebas.
  final AuditService? service;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late final AuditService _service =
      widget.service ?? AuditService(context.read<ApiClient>());

  final TextEditingController _desde = TextEditingController();
  final TextEditingController _hasta = TextEditingController();
  final TextEditingController _usuarioId = TextEditingController();
  String? _accion;

  PagedResult<AuditEntry>? _resultado;
  bool _loading = true;
  String? _error;
  int _pagina = 1;

  static final RegExp _fecha = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _desde.dispose();
    _hasta.dispose();
    _usuarioId.dispose();
    super.dispose();
  }

  String? _texto(TextEditingController c) {
    final String text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _load() async {
    final String? desde = _texto(_desde);
    final String? hasta = _texto(_hasta);
    if ((desde != null && !_fecha.hasMatch(desde)) || (hasta != null && !_fecha.hasMatch(hasta))) {
      setState(() => _error = 'Las fechas deben tener el formato AAAA-MM-DD.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final PagedResult<AuditEntry> resultado = await _service.list(
        filtros: AuditFilters(
          desde: desde,
          hasta: hasta,
          usuarioId: int.tryParse(_usuarioId.text.trim()),
          accion: _accion,
        ),
        pagina: _pagina,
      );
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.mensaje;
        _loading = false;
      });
    }
  }

  void _filtrar() {
    _pagina = 1;
    _load();
  }

  void _limpiar() {
    _desde.clear();
    _hasta.clear();
    _usuarioId.clear();
    setState(() => _accion = null);
    _filtrar();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final PagedResult<AuditEntry>? resultado = _resultado;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Bitácora', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Acciones sensibles del sistema. Solo consulta: no se puede editar ni borrar.',
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
                      key: const Key('bitacora-desde'),
                      controller: _desde,
                      decoration: const InputDecoration(labelText: 'Desde (AAAA-MM-DD)'),
                    ),
                  ),
                  SizedBox(
                    width: AppMetrics.comboboxWidth,
                    child: TextField(
                      key: const Key('bitacora-hasta'),
                      controller: _hasta,
                      decoration: const InputDecoration(labelText: 'Hasta (AAAA-MM-DD)'),
                    ),
                  ),
                  SizedBox(
                    width: AppMetrics.comboboxWidth,
                    child: TextField(
                      key: const Key('bitacora-usuario'),
                      controller: _usuarioId,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Id de usuario'),
                    ),
                  ),
                  SizedBox(
                    width: AppMetrics.comboboxWidth,
                    child: DropdownButtonFormField<String?>(
                      key: const Key('bitacora-accion'),
                      initialValue: _accion,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Acción'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                        for (final String accion in _service.acciones)
                          DropdownMenuItem<String?>(value: accion, child: Text(AuditEntry.label(accion))),
                      ],
                      onChanged: (String? value) => setState(() => _accion = value),
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('bitacora-filtrar'),
                    onPressed: _filtrar,
                    icon: const Icon(LucideIcons.funnel, size: AppMetrics.iconSizeSmall),
                    label: const Text('Filtrar'),
                  ),
                  TextButton(onPressed: _limpiar, child: const Text('Limpiar')),
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
            else if (resultado != null && resultado.elementos.isEmpty)
              const EmptyView(mensaje: 'No hay acciones registradas con esos filtros.')
            else if (resultado != null) ...<Widget>[
              Text('${resultado.total} registros', style: textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              AppPanel(
                padding: EdgeInsets.zero,
                child: FullWidthTable(
                  key: const Key('tabla-bitacora'),
                  columns: <DataColumn>[
                    fluidColumn('Fecha', weight: 2),
                    fluidColumn('Usuario'),
                    fluidColumn('Acción', weight: 2),
                    fluidColumn('Detalle', weight: 4),
                  ],
                  rows: <DataRow>[
                    for (final AuditEntry e in resultado.elementos)
                      DataRow(cells: <DataCell>[
                        DataCell(Text(Formatters.dateTime(e.fecha))),
                        DataCell(Text(e.usuario ?? 'Sin sesión')),
                        DataCell(Text(AuditEntry.label(e.accion))),
                        DataCell(Text(e.detalle ?? '—')),
                      ]),
                  ],
                ),
              ),
              PagerBar(
                pagina: resultado.pagina,
                paginas: resultado.paginas,
                onPage: (int pagina) {
                  _pagina = pagina;
                  _load();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
