import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/maintenance.dart';
import '../models/service_type.dart';
import '../models/vehicle.dart';
import '../providers/maintenance_provider.dart';
import '../providers/vehicles_provider.dart';
import '../services/api_client.dart';
import '../services/service_types_service.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../utils/validators.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';

/// Argumentos de la ruta del formulario de mantenimiento.
class MaintenanceFormArgs {
  const MaintenanceFormArgs({this.mantenimiento, this.vehiculoId});

  /// Si se pasa un mantenimiento, el formulario lo edita (FR-010) y ofrece
  /// «servicio realizado» (FR-015).
  final Maintenance? mantenimiento;

  /// Vehículo preseleccionado para el alta (por ejemplo desde su ficha).
  final int? vehiculoId;
}

/// Formulario de mantenimiento preventivo (US3/HU3): alta y edición con
/// objetivo por fecha y/o kilometraje (SC-004, sin conocimientos técnicos) y
/// la acción «servicio realizado» con confirmación obligatoria.
class MaintenanceFormScreen extends StatefulWidget {
  const MaintenanceFormScreen({
    super.key,
    required this.args,
    this.serviceTypesService,
    this.hoy,
  });

  final MaintenanceFormArgs args;

  /// Sprint 7 (US3, FR-011): catálogo de tipos para proponer el próximo
  /// mantenimiento. Inyectable en pruebas; si no se pasa, se crea con el
  /// cliente HTTP de la app (sin él, el formulario funciona como antes).
  final ServiceTypesService? serviceTypesService;

  /// Fecha base de la propuesta (inyectable en pruebas; por defecto hoy).
  final DateTime? hoy;

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _tipoController;
  late final TextEditingController _fechaObjetivoController;
  late final TextEditingController _kmObjetivoController;
  late final TextEditingController _intervaloDiasController;
  late final TextEditingController _intervaloKmController;
  late final TextEditingController _antelacionDiasController;
  late final TextEditingController _antelacionKmController;
  late final TextEditingController _notasController;

  int? _vehiculoId;
  String? _error;
  bool _saving = false;

  // Sprint 7 (US3): tipos activos del catálogo y el elegido.
  List<ServiceType> _tipos = const <ServiceType>[];
  int? _tipoCatalogoId;

  bool get _esEdicion => widget.args.mantenimiento != null;

  @override
  void initState() {
    super.initState();
    final Maintenance? actual = widget.args.mantenimiento;
    _vehiculoId = actual?.vehiculoId ?? widget.args.vehiculoId;

    _tipoController = TextEditingController(text: actual?.tipoServicio ?? '');
    _fechaObjetivoController =
        TextEditingController(text: actual?.fechaObjetivo ?? '');
    _kmObjetivoController = TextEditingController(
      text: actual?.kilometrajeObjetivo?.toString() ?? '',
    );
    _intervaloDiasController = TextEditingController(
      text: actual?.intervaloDias?.toString() ?? '',
    );
    _intervaloKmController = TextEditingController(
      text: actual?.intervaloKm?.toString() ?? '',
    );
    // Sprint 7 (US2, FR-005): en el alta la antelación queda vacía y el
    // backend aplica los márgenes configurados por el administrador; en la
    // edición se muestra la propia del registro.
    _antelacionDiasController =
        TextEditingController(text: actual?.antelacionDias.toString() ?? '');
    _antelacionKmController =
        TextEditingController(text: actual?.antelacionKm.toString() ?? '');
    _notasController = TextEditingController(text: actual?.notas ?? '');

    if (!_esEdicion) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTipos());
    }

    // En alta sin vehículo preseleccionado se carga el selector (FR-001).
    if (!_esEdicion && _vehiculoId == null) {
      final VehiclesProvider vehicles = context.read<VehiclesProvider>();
      if (vehicles.items.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            vehicles.load();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _tipoController.dispose();
    _fechaObjetivoController.dispose();
    _kmObjetivoController.dispose();
    _intervaloDiasController.dispose();
    _intervaloKmController.dispose();
    _antelacionDiasController.dispose();
    _antelacionKmController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _cargarTipos() async {
    ServiceTypesService? service = widget.serviceTypesService;
    if (service == null) {
      try {
        service = ServiceTypesService(context.read<ApiClient>());
      } on ProviderNotFoundException {
        return;
      }
    }
    try {
      final List<ServiceType> tipos = await service.list();
      if (mounted) setState(() => _tipos = tipos);
    } on ApiException {
      // Sin catálogo el formulario sigue funcionando con captura manual.
    }
  }

  /// Kilometraje actual del vehículo elegido, si se conoce.
  int? _kilometrajeActual() {
    final int? id = _vehiculoId;
    if (id == null) return null;
    try {
      for (final Vehicle v in context.read<VehiclesProvider>().items) {
        if (v.id == id) return v.kilometrajeActual;
      }
    } on ProviderNotFoundException {
      return null;
    }
    return null;
  }

  /// FR-011: propone tipo, intervalos, fecha (hoy + días) y kilometraje
  /// (actual + km); el usuario puede corregir cualquiera antes de guardar.
  void _elegirTipo(int? id) {
    setState(() => _tipoCatalogoId = id);
    if (id == null) return;
    final ServiceType tipo = _tipos.firstWhere((ServiceType t) => t.id == id);
    final NextServiceProposal propuesta = NextServiceProposal.from(
      tipo,
      hoy: widget.hoy ?? DateTime.now(),
      kilometrajeActual: _kilometrajeActual(),
    );
    _tipoController.text = tipo.nombre;
    _intervaloDiasController.text = tipo.intervaloDias?.toString() ?? '';
    _intervaloKmController.text = tipo.intervaloKm?.toString() ?? '';
    _fechaObjetivoController.text = propuesta.fecha ?? '';
    _kmObjetivoController.text = propuesta.kilometraje?.toString() ?? '';
  }

  Widget _buildServiceTypeSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: DropdownButtonFormField<int?>(
        key: const Key('mantenimiento-tipo-catalogo'),
        initialValue: _tipoCatalogoId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Tipo del catálogo (opcional)',
          helperText: 'Propone el intervalo, la fecha y el kilometraje; puedes corregirlos.',
          prefixIcon: Icon(LucideIcons.listChecks, size: AppMetrics.iconSizeSmall),
        ),
        items: <DropdownMenuItem<int?>>[
          const DropdownMenuItem<int?>(value: null, child: Text('Captura manual')),
          for (final ServiceType tipo in _tipos)
            DropdownMenuItem<int?>(
              value: tipo.id,
              child: Text('${tipo.nombre} · ${tipo.intervaloTexto}', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _saving ? null : _elegirTipo,
      ),
    );
  }

  int? _numero(TextEditingController controller) {
    final String texto = controller.text.trim();
    return texto.isEmpty ? null : int.tryParse(texto);
  }

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    // RN-11: al menos un objetivo (el backend también lo exige con
    // OBJETIVO_REQUERIDO; aquí se evita el viaje).
    if (_fechaObjetivoController.text.trim().isEmpty &&
        _numero(_kmObjetivoController) == null) {
      setState(
        () => _error = 'Indica la fecha o el kilometraje del próximo servicio.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final MaintenanceProvider provider =
        context.read<MaintenanceProvider>();
    try {
      final Maintenance? actual = widget.args.mantenimiento;
      if (actual == null) {
        if (_vehiculoId == null) {
          setState(() {
            _saving = false;
            _error = 'Selecciona el vehículo del mantenimiento.';
          });
          return;
        }
        await provider.create(
          vehiculoId: _vehiculoId!,
          tipoServicio: _tipoController.text.trim(),
          fechaObjetivo: _fechaObjetivoController.text.trim(),
          kilometrajeObjetivo: _numero(_kmObjetivoController),
          intervaloDias: _numero(_intervaloDiasController),
          intervaloKm: _numero(_intervaloKmController),
          antelacionDias: _numero(_antelacionDiasController),
          antelacionKm: _numero(_antelacionKmController),
          notas: _notasController.text.trim(),
        );
      } else {
        await provider.update(
          id: actual.id,
          vehiculoId: actual.vehiculoId,
          tipoServicio: _tipoController.text.trim(),
          fechaObjetivo: _fechaObjetivoController.text.trim(),
          kilometrajeObjetivo: _numero(_kmObjetivoController),
          intervaloDias: _numero(_intervaloDiasController),
          intervaloKm: _numero(_intervaloKmController),
          antelacionDias: _numero(_antelacionDiasController),
          antelacionKm: _numero(_antelacionKmController),
          notas: _notasController.text.trim(),
        );
      }

      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actual == null
                ? 'Mantenimiento programado correctamente.'
                : 'Mantenimiento actualizado correctamente.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = e.mensaje;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = AppMessages.unexpectedError;
      });
    }
  }

  /// Marca «servicio realizado» (FR-015) con confirmación obligatoria: el
  /// backend renueva el mismo registro y recalcula el próximo objetivo.
  Future<void> _realizar() async {
    final Maintenance? actual = widget.args.mantenimiento;
    if (actual == null) {
      return;
    }
    final bool confirmado = await showConfirmDialog(
      context,
      titulo: 'Marcar servicio realizado',
      mensaje: 'Se registrará el servicio de hoy con el kilometraje vigente '
          'del vehículo y el próximo objetivo se recalculará con el intervalo '
          'configurado. ¿Continuar?',
      confirmarLabel: 'Marcar realizado',
    );
    if (!confirmado || !mounted) {
      return;
    }

    setState(() => _saving = true);
    final MaintenanceProvider provider =
        context.read<MaintenanceProvider>();
    try {
      final Maintenance renovado = await provider.realizar(actual.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = null;
        _fechaObjetivoController.text = renovado.fechaObjetivo ?? '';
        _kmObjetivoController.text =
            renovado.kilometrajeObjetivo?.toString() ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servicio realizado. El mantenimiento se renovó.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = e.mensaje;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = AppMessages.unexpectedError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Maintenance? actual = widget.args.mantenimiento;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const BackAction(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _esEdicion ? 'Editar mantenimiento' : 'Programar mantenimiento',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _esEdicion
                  ? 'Ajusta el objetivo y el intervalo del servicio preventivo.'
                  : 'Define el próximo servicio preventivo del vehículo: al '
                      'menos un objetivo de fecha o kilometraje.',
              style: textTheme.bodySmall?.copyWith(
                color: context.motorixColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPanel(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_error != null && _error!.isNotEmpty) ...<Widget>[
                      FormErrorBanner(mensaje: _error!),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (!_esEdicion && _vehiculoId == null)
                      _buildVehicleSelector(),
                    if (!_esEdicion && _tipos.isNotEmpty)
                      _buildServiceTypeSelector(),
                    TextFormField(
                      controller: _tipoController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de servicio *',
                        hintText: 'Ej. Cambio de aceite y filtro',
                        prefixIcon: Icon(
                          LucideIcons.wrench,
                          size: AppMetrics.iconSizeSmall,
                        ),
                      ),
                      validator: (String? value) =>
                          Validators.required(value, 'el tipo de servicio'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Próximo objetivo',
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _fechaObjetivoController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Fecha del próximo servicio',
                        hintText: 'AAAA-MM-DD (opcional)',
                        prefixIcon: Icon(
                          LucideIcons.calendar,
                          size: AppMetrics.iconSizeSmall,
                        ),
                      ),
                      validator: Validators.optionalFecha,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _kmObjetivoController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kilometraje objetivo',
                        hintText: 'Ej. 45000 (opcional)',
                        prefixIcon: Icon(
                          LucideIcons.gauge,
                          size: AppMetrics.iconSizeSmall,
                        ),
                      ),
                      validator: (String? value) =>
                          Validators.optionalNonNegativeInt(
                        value,
                        'el kilometraje objetivo',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Intervalo y antelación',
                      style: textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _intervaloDiasController,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Intervalo en días',
                              hintText: 'Sin intervalo por fecha',
                              prefixIcon: Icon(
                                LucideIcons.calendarDays,
                                size: AppMetrics.iconSizeSmall,
                              ),
                            ),
                            validator: (String? value) =>
                                Validators.optionalPositiveInt(
                              value,
                              'el intervalo en días',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: TextFormField(
                            controller: _intervaloKmController,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Intervalo en km',
                              hintText: 'Sin intervalo por km',
                              prefixIcon: Icon(
                                LucideIcons.route,
                                size: AppMetrics.iconSizeSmall,
                              ),
                            ),
                            validator: (String? value) =>
                                Validators.optionalPositiveInt(
                              value,
                              'el intervalo en kilómetros',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _antelacionDiasController,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Avisar con anticipación (días)',
                              hintText: 'Vacío = margen del taller',
                              prefixIcon: Icon(
                                LucideIcons.bell,
                                size: AppMetrics.iconSizeSmall,
                              ),
                            ),
                            validator: (String? value) =>
                                Validators.optionalPositiveInt(
                              value,
                              'la antelación en días',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: TextFormField(
                            controller: _antelacionKmController,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Avisar con anticipación (km)',
                              hintText: 'Vacío = margen del taller',
                              prefixIcon: Icon(
                                LucideIcons.bellRing,
                                size: AppMetrics.iconSizeSmall,
                              ),
                            ),
                            validator: (String? value) =>
                                Validators.optionalPositiveInt(
                              value,
                              'la antelación en kilómetros',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _notasController,
                      enabled: !_saving,
                      maxLines: 3,
                      maxLength: 255,
                      decoration: const InputDecoration(
                        labelText: 'Notas',
                        hintText: 'Detalles útiles para el servicio (opcional)',
                        prefixIcon: Icon(
                          LucideIcons.notepadText,
                          size: AppMetrics.iconSizeSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FormActions(
                      onCancel: () => Navigator.pop(context, false),
                      onSave: _save,
                      saveLabel:
                          _esEdicion ? 'Guardar cambios' : 'Programar',
                      saving: _saving,
                    ),
                  ],
                ),
              ),
            ),
            if (_esEdicion && actual != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Servicio realizado', style: textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Registra el servicio de hoy, renueva este mismo '
                      'mantenimiento y recalcula el próximo objetivo.',
                      style: textTheme.bodySmall?.copyWith(
                        color: context.motorixColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _realizar,
                      icon: const Icon(
                        LucideIcons.circleCheck,
                        size: AppMetrics.iconSizeSmall,
                      ),
                      label: const Text('Marcar servicio realizado'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleSelector() {
    final VehiclesProvider vehicles = context.watch<VehiclesProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: DropdownButtonFormField<int>(
        initialValue: _vehiculoId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Vehículo *',
          prefixIcon: Icon(
            LucideIcons.carFront,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
        items: <DropdownMenuItem<int>>[
          for (final Vehicle vehicle in vehicles.items)
            DropdownMenuItem<int>(
              value: vehicle.id,
              child: Text(
                '${vehicle.descripcion} ${vehicle.anio} · ${vehicle.placas}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: _saving
            ? null
            : (int? value) => setState(() => _vehiculoId = value),
        validator: (int? value) => (value == null && !_esEdicion)
            ? 'Selecciona el vehículo del mantenimiento.'
            : null,
      ),
    );
  }
}
