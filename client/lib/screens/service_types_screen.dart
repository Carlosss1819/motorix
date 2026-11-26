import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/service_type.dart';
import '../services/api_client.dart';
import '../services/service_types_service.dart';
import '../utils/app_theme.dart';
import '../widgets/app_table.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';

/// Catálogo de tipos de servicio con intervalo (Sprint 7, US3). Solo ADMIN:
/// alta y edición en diálogo, activar y desactivar con confirmación. Los
/// tipos no se borran (FR-008).
class ServiceTypesScreen extends StatefulWidget {
  const ServiceTypesScreen({super.key, this.service});

  /// Servicio inyectable para las pruebas.
  final ServiceTypesService? service;

  @override
  State<ServiceTypesScreen> createState() => _ServiceTypesScreenState();
}

class _ServiceTypesScreenState extends State<ServiceTypesScreen> {
  late final ServiceTypesService _service =
      widget.service ?? ServiceTypesService(context.read<ApiClient>());

  List<ServiceType> _tipos = const <ServiceType>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<ServiceType> tipos = await _service.list(incluirInactivos: true);
      if (!mounted) return;
      setState(() {
        _tipos = tipos;
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

  void _mensaje(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _abrirFormulario([ServiceType? tipo]) async {
    final bool? guardado = await showAppDialog<bool>(
      context: context,
      builder: (_) => _ServiceTypeDialog(service: _service, tipo: tipo),
    );
    if (guardado == true) {
      _mensaje(tipo == null ? 'Tipo de servicio creado.' : 'Tipo de servicio actualizado.');
      _load();
    }
  }

  Future<void> _cambiarEstado(ServiceType tipo) async {
    final bool activar = !tipo.activo;
    final bool ok = await showConfirmDialog(
      context,
      titulo: activar ? 'Activar tipo de servicio' : 'Desactivar tipo de servicio',
      mensaje: activar
          ? '«${tipo.nombre}» volverá a ofrecerse al registrar servicios y mantenimientos.'
          : '«${tipo.nombre}» dejará de ofrecerse en las listas. Las órdenes que ya lo usan lo conservan.',
      confirmarLabel: activar ? 'Activar' : 'Desactivar',
      destructive: !activar,
    );
    if (!ok) return;
    try {
      await _service.setActive(tipo.id, activo: activar);
      if (!mounted) return;
      _mensaje(activar ? 'Tipo de servicio activado.' : 'Tipo de servicio desactivado.');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      _mensaje(e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(mensaje: _error!, onRetry: _load);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text('Tipos de servicio', style: textTheme.titleLarge)),
                FilledButton.icon(
                  key: const Key('tipo-nuevo'),
                  onPressed: () => _abrirFormulario(),
                  icon: const Icon(LucideIcons.plus, size: AppMetrics.iconSizeSmall),
                  label: const Text('Nuevo tipo'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'El intervalo propone el próximo mantenimiento y el próximo servicio del ticket.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_tipos.isEmpty)
              EmptyView(
                mensaje: 'Aún no hay tipos de servicio.',
                actionLabel: 'Nuevo tipo',
                onAction: () => _abrirFormulario(),
              )
            else
              AppPanel(
                padding: EdgeInsets.zero,
                child: FullWidthTable(
                  columns: <DataColumn>[
                    fluidColumn('Tipo de servicio', weight: 3),
                    fluidColumn('Intervalo', weight: 2),
                    fluidColumn('Estado'),
                    fluidColumn('Acciones', weight: 2),
                  ],
                  rows: <DataRow>[
                    for (final ServiceType tipo in _tipos)
                      DataRow(
                        key: ValueKey<int>(tipo.id),
                        cells: <DataCell>[
                          DataCell(Text(tipo.nombre)),
                          DataCell(Text(tipo.intervaloTexto)),
                          DataCell(StatusChip(activo: tipo.activo)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  key: Key('tipo-editar-${tipo.id}'),
                                  tooltip: 'Editar',
                                  onPressed: () => _abrirFormulario(tipo),
                                  icon: const Icon(LucideIcons.pencil, size: AppMetrics.iconSizeSmall),
                                ),
                                TextButton(
                                  key: Key('tipo-estado-${tipo.id}'),
                                  onPressed: () => _cambiarEstado(tipo),
                                  style: TextButton.styleFrom(
                                    foregroundColor: tipo.activo ? colors.danger : colors.success,
                                  ),
                                  child: Text(tipo.activo ? 'Desactivar' : 'Activar'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Alta y edición de un tipo de servicio: nombre y al menos un intervalo.
class _ServiceTypeDialog extends StatefulWidget {
  const _ServiceTypeDialog({required this.service, this.tipo});

  final ServiceTypesService service;
  final ServiceType? tipo;

  @override
  State<_ServiceTypeDialog> createState() => _ServiceTypeDialogState();
}

class _ServiceTypeDialogState extends State<_ServiceTypeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre =
      TextEditingController(text: widget.tipo?.nombre ?? '');
  late final TextEditingController _dias =
      TextEditingController(text: widget.tipo?.intervaloDias?.toString() ?? '');
  late final TextEditingController _km =
      TextEditingController(text: widget.tipo?.intervaloKm?.toString() ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _dias.dispose();
    _km.dispose();
    super.dispose();
  }

  int? _valor(TextEditingController c) => int.tryParse(c.text.trim());

  String? _validarIntervalo(String? value, int max) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _dias.text.trim().isEmpty && _km.text.trim().isEmpty
          ? 'Indica al menos un intervalo: en días o en kilómetros.'
          : null;
    }
    final int? number = int.tryParse(text);
    if (number == null || number < 1 || number > max) {
      return 'Debe ser un entero entre 1 y $max.';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ServiceTypeInput input = ServiceTypeInput(
      nombre: _nombre.text.trim(),
      intervaloDias: _valor(_dias),
      intervaloKm: _valor(_km),
    );
    try {
      if (widget.tipo == null) {
        await widget.service.create(input);
      } else {
        await widget.service.update(widget.tipo!.id, input);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tipo == null ? 'Nuevo tipo de servicio' : 'Editar tipo de servicio'),
      content: SizedBox(
        width: AppMetrics.formDialogWidth,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_error != null) ...<Widget>[
                FormErrorBanner(mensaje: _error!),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                key: const Key('tipo-nombre'),
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (String? v) {
                  final String text = v?.trim() ?? '';
                  if (text.isEmpty) return 'Ingresa el nombre del tipo de servicio.';
                  if (text.length > 120) return 'El nombre no puede exceder 120 caracteres.';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const Key('tipo-dias'),
                controller: _dias,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Intervalo en días (opcional)'),
                validator: (String? v) => _validarIntervalo(v, 3650),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const Key('tipo-km'),
                controller: _km,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Intervalo en kilómetros (opcional)'),
                validator: (String? v) => _validarIntervalo(v, 500000),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('tipo-guardar'),
          onPressed: _saving ? null : _guardar,
          child: Text(_saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }
}
