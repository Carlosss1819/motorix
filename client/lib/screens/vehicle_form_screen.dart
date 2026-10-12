import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../models/vehicle.dart';
import '../providers/clients_provider.dart';
import '../providers/load_status.dart';
import '../providers/vehicles_provider.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../utils/validators.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';

/// Argumento de la ruta de alta o edición de vehículo.
class VehicleFormArgs {
  const VehicleFormArgs({this.vehicle, this.clienteId});

  /// Si se pasa un vehículo, el formulario entra en modo edición.
  final Vehicle? vehicle;

  /// Propietario preseleccionado (por ejemplo, desde la ficha de un cliente).
  final int? clienteId;
}

/// Formulario de vehículo (US5): propietario obligatorio, placas únicas, VIN
/// opcional y kilometraje mayor o igual que cero.
class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle, this.clienteId});

  final Vehicle? vehicle;
  final int? clienteId;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _marcaController;
  late final TextEditingController _modeloController;
  late final TextEditingController _anioController;
  late final TextEditingController _placasController;
  late final TextEditingController _vinController;
  late final TextEditingController _kilometrajeController;

  late int? _clienteId;
  late int? _clienteIdInicial;

  String _error = '';
  bool _saving = false;

  bool get _esEdicion => widget.vehicle != null;

  bool get _dirty =>
      _marcaController.text != (widget.vehicle?.marca ?? '') ||
      _modeloController.text != (widget.vehicle?.modelo ?? '') ||
      _anioController.text != (widget.vehicle == null ? '' : '${widget.vehicle!.anio}') ||
      _placasController.text != (widget.vehicle?.placas ?? '') ||
      _vinController.text != (widget.vehicle?.vin ?? '') ||
      _kilometrajeController.text !=
          (widget.vehicle == null ? '' : '${widget.vehicle!.kilometrajeActual}') ||
      _clienteId != _clienteIdInicial;

  @override
  void initState() {
    super.initState();
    final Vehicle? vehicle = widget.vehicle;
    _marcaController = TextEditingController(text: vehicle?.marca ?? '');    _modeloController = TextEditingController(text: vehicle?.modelo ?? '');
    _anioController =
        TextEditingController(text: vehicle == null ? '' : '${vehicle.anio}');
    _placasController = TextEditingController(text: vehicle?.placas ?? '');
    _vinController = TextEditingController(text: vehicle?.vin ?? '');
    _kilometrajeController = TextEditingController(
      text: vehicle == null ? '' : '${vehicle.kilometrajeActual}',
    );
    _clienteId = vehicle?.clienteId ?? widget.clienteId;
    _clienteIdInicial = _clienteId;

    // El selector de propietario necesita la lista de clientes; se carga aquí
    // por si el formulario se abre antes de visitar la lista de clientes.
    final ClientsProvider clientes = context.read<ClientsProvider>();
    if (clientes.items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        clientes.load();
      });
    }
  }

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _placasController.dispose();
    _vinController.dispose();
    _kilometrajeController.dispose();
    super.dispose();
  }

  /// Salir pidiendo confirmación si hay cambios sin guardar (8.5).
  Future<void> _confirmExit() async {
    if (!_dirty) {
      Navigator.maybePop(context);
      return;
    }
    final bool ok = await confirmDiscardChanges(context);
    if (!ok || !mounted) {
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    final VehiclesProvider vehicles = context.read<VehiclesProvider>();
    final int anio = int.parse(_anioController.text.trim());
    final int kilometraje = int.parse(_kilometrajeController.text.trim());

    try {
      if (_esEdicion) {
        await vehicles.update(
          id: widget.vehicle!.id,
          clienteId: _clienteId!,
          marca: _marcaController.text.trim(),
          modelo: _modeloController.text.trim(),
          anio: anio,
          placas: _placasController.text.trim(),
          vin: _vinController.text.trim(),
          kilometrajeActual: kilometraje,
        );
      } else {
        await vehicles.create(
          clienteId: _clienteId!,
          marca: _marcaController.text.trim(),
          modelo: _modeloController.text.trim(),
          anio: anio,
          placas: _placasController.text.trim(),
          vin: _vinController.text.trim(),
          kilometrajeActual: kilometraje,
        );
      }

      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion
                ? 'Vehículo actualizado correctamente.'
                : 'Vehículo registrado correctamente.',
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

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ClientsProvider clients = context.watch<ClientsProvider>();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _confirmExit();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const BackAction(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _esEdicion ? 'Editar vehículo' : 'Registrar vehículo',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _esEdicion
                    ? 'Actualiza los datos del vehículo. El propietario no se '
                      'cambia en esta versión.'
                    : 'Selecciona el propietario y completa los datos del '
                      'automóvil. Las placas y el VIN deben ser únicos.',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPanel(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_error.isNotEmpty) ...<Widget>[
                        FormErrorBanner(mensaje: _error),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _buildOwnerField(clients),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _marcaController,
                              enabled: !_saving,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Marca *',
                                hintText: 'Ej. Nissan',
                                prefixIcon: Icon(
                                  LucideIcons.carFront,
                                  size: AppMetrics.iconSizeSmall,
                                ),
                              ),
                              validator: (String? value) =>
                                  Validators.required(value, 'la marca'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: TextFormField(
                              controller: _modeloController,
                              enabled: !_saving,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Modelo *',
                                hintText: 'Ej. Versa',
                              ),
                              validator: (String? value) =>
                                  Validators.required(value, 'el modelo'),
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
                              controller: _anioController,
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Año *',
                                hintText: 'Ej. 2020',
                              ),
                              validator: Validators.year,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: TextFormField(
                              controller: _placasController,
                              enabled: !_saving,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Placas *',
                                hintText: 'Ej. ABC1234',
                              ),
                              validator: (String? value) =>
                                  Validators.required(value, 'las placas'),
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
                              controller: _vinController,
                              enabled: !_saving,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'VIN (opcional)',
                                hintText: 'Número de serie',
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: TextFormField(
                              controller: _kilometrajeController,
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Kilometraje actual *',
                                hintText: 'Ej. 45000',
                              ),
                              validator: Validators.mileage,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FormActions(
                        onCancel: _confirmExit,
                        onSave: _save,
                        saveLabel:
                            _esEdicion ? 'Guardar cambios' : 'Registrar vehículo',
                        saving: _saving,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerField(ClientsProvider clients) {
    if (clients.items.isEmpty &&
        clients.status == LoadStatus.loading) {
      return Row(
        children: <Widget>[
          const SizedBox(
            width: AppMetrics.spinnerSize,
            height: AppMetrics.spinnerSize,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Cargando propietarios…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    if (clients.items.isEmpty) {
      final bool hayError = clients.status == LoadStatus.error;
      return AppPanel(
        expand: false,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              hayError
                  ? clients.error ?? AppMessages.unexpectedError
                  : 'No hay clientes registrados todavía. Da de alta un '
                        'cliente antes de registrar un vehículo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: clients.isLoading ? null : clients.load,
              icon: const Icon(
                LucideIcons.refreshCw,
                size: AppMetrics.iconSizeSmall,
              ),
              label: const Text('Recargar propietarios'),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _clienteId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Propietario *',
        prefixIcon: Icon(
          LucideIcons.userRound,
          size: AppMetrics.iconSizeSmall,
        ),
      ),
      items: <DropdownMenuItem<int>>[
        for (final Client cliente in clients.items)
          DropdownMenuItem<int>(
            value: cliente.id,
            child: Text(
              cliente.nombre,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _saving ? null : (int? value) => setState(() => _clienteId = value),
      validator: (int? value) => value == null
          ? 'Selecciona el propietario del vehículo.'
          : null,
    );
  }
}
