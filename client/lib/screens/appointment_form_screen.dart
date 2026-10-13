import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/client.dart';
import '../models/vehicle.dart';
import '../providers/appointments_provider.dart';
import '../providers/clients_provider.dart';
import '../providers/load_status.dart';
import '../providers/vehicles_provider.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../utils/validators.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';

/// Argumento de la ruta de alta o edición de cita.
class AppointmentFormArgs {
  const AppointmentFormArgs({this.cita});

  /// Si se pasa una cita, el formulario entra en modo edición.
  final Appointment? cita;
}

/// Formulario de cita de recepción (US2/HU2): cliente, vehículo, fecha, hora
/// y motivo obligatorios (FR-005). Ante un conflicto de horario (FR-008)
/// muestra el aviso del backend y permite reenviar con confirmación.
class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({super.key, this.cita});

  /// Cita a editar; `null` significa alta.
  final Appointment? cita;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _motivoController;
  late final TextEditingController _fechaController;
  late final TextEditingController _horaController;

  int? _clienteId;
  int? _vehiculoId;

  List<Vehicle> _vehiculos = const <Vehicle>[];
  bool _cargandoVehiculos = false;
  String? _errorVehiculos;

  String _error = '';
  String? _conflicto;
  bool _saving = false;

  bool get _esEdicion => widget.cita != null;

  @override
  void initState() {
    super.initState();
    final Appointment? cita = widget.cita;
    _motivoController = TextEditingController(text: cita?.motivo ?? '');
    _fechaController = TextEditingController(text: cita?.fecha ?? hoyIso());
    _horaController = TextEditingController(text: cita?.hora ?? '');
    // En edición cliente y vehículo no cambian (contrato, sección PUT).
    _clienteId = cita?.clienteId;
    _vehiculoId = cita?.vehiculoId;

    // El selector de clientes necesita la lista; se carga aquí por si el
    // formulario se abre antes de visitar el listado.
    final ClientsProvider clientes = context.read<ClientsProvider>();
    if (clientes.items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        clientes.load();
      });
    }
    if (_clienteId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _cargarVehiculos(_clienteId!);
      });
    }
  }

  @override
  void dispose() {
    _motivoController.dispose();
    _fechaController.dispose();
    _horaController.dispose();
    super.dispose();
  }

  bool get _dirty {
    final Appointment? cita = widget.cita;
    if (cita != null) {
      return _motivoController.text.trim() != cita.motivo ||
          _fechaController.text.trim() != cita.fecha ||
          _horaController.text.trim() != cita.hora;
    }
    return _motivoController.text.trim().isNotEmpty ||
        _horaController.text.trim().isNotEmpty ||
        _clienteId != null ||
        _fechaController.text.trim() != hoyIso();
  }

  /// Salir pidiendo confirmación si hay cambios sin guardar (Principio VIII).
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

  /// Carga los vehículos del cliente elegido; vacío significa que ese cliente
  /// aún no tiene ninguno registrado.
  Future<void> _cargarVehiculos(int clienteId) async {
    setState(() {
      _cargandoVehiculos = true;
      _errorVehiculos = null;
      _vehiculos = const <Vehicle>[];
      _vehiculoId = null;
    });

    final VehiclesProvider vehiculos = context.read<VehiclesProvider>();
    await vehiculos.load(clienteId: clienteId);
    if (!mounted) {
      return;
    }
    setState(() {
      _vehiculos = vehiculos.items;
      _cargandoVehiculos = false;
      _errorVehiculos =
          vehiculos.status == LoadStatus.error
              ? vehiculos.error ?? AppMessages.unexpectedError
              : null;
    });
  }

  void _onClienteChanged(int? clienteId) {
    if (clienteId == null || clienteId == _clienteId) {
      return;
    }
    setState(() => _clienteId = clienteId);
    _cargarVehiculos(clienteId);
  }

  void _onVehiculoChanged(int? vehiculoId) {
    if (vehiculoId == null || vehiculoId == _vehiculoId) {
      return;
    }
    final int indice = _vehiculos.indexWhere((Vehicle v) => v.id == vehiculoId);
    if (indice < 0) {
      return;
    }
    setState(() => _vehiculoId = vehiculoId);
  }

  String? _validarFecha(String? value) {
    final String texto = value?.trim() ?? '';
    if (texto.isEmpty) {
      return 'Escribe la fecha de la cita.';
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) {
      return 'La fecha debe tener el formato AAAA-MM-DD.';
    }
    final DateTime? fecha = DateTime.tryParse(texto);
    if (fecha == null || fecha.toIso8601String().substring(0, 10) != texto) {
      return 'Escribe una fecha válida.';
    }
    return null;
  }

  String? _validarHora(String? value) {
    final String texto = value?.trim() ?? '';
    if (texto.isEmpty) {
      return 'Escribe la hora de la cita.';
    }
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(texto)) {
      return 'La hora debe tener el formato HH:MM (de 00:00 a 23:59).';
    }
    return null;
  }

  String? _validarMotivo(String? value) {
    final String? requerido = Validators.required(value, 'el motivo de la cita');
    if (requerido != null) {
      return 'Escribe el motivo de la cita.';
    }
    if (value!.trim().length > 255) {
      return 'El motivo de la cita no puede exceder 255 caracteres.';
    }
    return null;
  }

  /// Guarda la cita; con [confirmar] vuelve a enviar tras un conflicto de
  /// horario (FR-008).
  Future<void> _save({bool confirmar = false}) async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_cargandoVehiculos || _clienteId == null || _vehiculoId == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    final AppointmentsProvider citas = context.read<AppointmentsProvider>();
    try {
      if (_esEdicion) {
        await citas.update(
          id: widget.cita!.id,
          clienteId: _clienteId!,
          vehiculoId: _vehiculoId!,
          fecha: _fechaController.text.trim(),
          hora: _horaController.text.trim(),
          motivo: _motivoController.text.trim(),
        );
      } else {
        await citas.create(
          clienteId: _clienteId!,
          vehiculoId: _vehiculoId!,
          fecha: _fechaController.text.trim(),
          hora: _horaController.text.trim(),
          motivo: _motivoController.text.trim(),
          confirmar: confirmar,
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
                ? 'Cita actualizada correctamente.'
                : 'Cita registrada correctamente.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      // Solo el alta permite confirmar el reenvío; la edición no (contrato).
      final bool conflictoReenviable =
          e.codigo == 'CITA_CONFLICTO_HORARIO' && !_esEdicion && !confirmar;
      setState(() {
        _saving = false;
        _conflicto = conflictoReenviable ? e.mensaje : null;
        _error = conflictoReenviable ? '' : e.mensaje;
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
                _esEdicion ? 'Editar cita' : 'Registrar cita',
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _esEdicion
                    ? 'Actualiza la fecha, la hora o el motivo de la cita. '
                          'El cliente y el vehículo no cambian.'
                    : 'Selecciona el cliente y el vehículo, y define la fecha '
                          'y la hora de la cita. La cita nace como programada.',
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
                      if (_conflicto != null) ...<Widget>[
                        _buildConflictoPanel(),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _buildClienteField(clients),
                      const SizedBox(height: AppSpacing.lg),
                      _buildVehiculoField(),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _fechaController,
                              enabled: !_saving,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: 'Fecha de la cita *',
                                hintText: 'AAAA-MM-DD',
                                prefixIcon: Icon(
                                  LucideIcons.calendar,
                                  size: AppMetrics.iconSizeSmall,
                                ),
                              ),
                              validator: _validarFecha,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: TextFormField(
                              controller: _horaController,
                              enabled: !_saving,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: 'Hora de la cita *',
                                hintText: 'HH:MM',
                                prefixIcon: Icon(
                                  LucideIcons.clock,
                                  size: AppMetrics.iconSizeSmall,
                                ),
                              ),
                              validator: _validarHora,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _motivoController,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Motivo de la cita *',
                          hintText: 'Ej. Revisión de frenos',
                          prefixIcon: Icon(
                            LucideIcons.clipboardList,
                            size: AppMetrics.iconSizeSmall,
                          ),
                        ),
                        validator: _validarMotivo,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FormActions(
                        onCancel: _confirmExit,
                        onSave: _save,
                        saveLabel: _esEdicion ? 'Guardar cambios' : 'Guardar cita',
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

  /// Aviso de conflicto de horario (FR-008) con el reenvío confirmado.
  Widget _buildConflictoPanel() {
    return AppPanel(
      expand: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_conflicto!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _save(confirmar: true),
            icon: const Icon(
              LucideIcons.check,
              size: AppMetrics.iconSizeSmall,
            ),
            label: const Text('Guardar de todos modos'),
          ),
        ],
      ),
    );
  }

  /// En edición cliente y vehículo son de solo lectura; el alta usa los
  /// selectores (el vehículo depende del cliente, RN-01).
  Widget _buildClienteField(ClientsProvider clients) {
    final Appointment? cita = widget.cita;
    if (cita != null) {
      // En edición el cliente no cambia (contrato, sección PUT).
      return DetailRow(label: 'Cliente', value: cita.cliente);
    }

    if (clients.items.isEmpty && clients.status == LoadStatus.loading) {
      return _cargandoFila('Cargando clientes…');
    }

    if (clients.items.isEmpty) {
      final bool hayError = clients.status == LoadStatus.error;
      return _aviso(
        hayError
            ? clients.error ?? AppMessages.unexpectedError
            : 'No hay clientes registrados todavía. Da de alta un cliente '
                  'antes de registrar una cita.',
        accionLabel: hayError ? 'Recargar clientes' : null,
        onAction: hayError ? clients.load : null,
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _clienteId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Cliente *',
        prefixIcon: Icon(
          LucideIcons.userRound,
          size: AppMetrics.iconSizeSmall,
        ),
      ),
      items: <DropdownMenuItem<int>>[
        for (final Client cliente in clients.items)
          DropdownMenuItem<int>(
            value: cliente.id,
            child: Text(cliente.nombre, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _saving ? null : _onClienteChanged,
      validator: (int? value) =>
          value == null ? 'Selecciona el cliente de la cita.' : null,
    );
  }

  Widget _buildVehiculoField() {
    final Appointment? cita = widget.cita;
    if (cita != null) {
      return DetailRow(
        label: 'Vehículo',
        value: '${cita.vehiculo} · ${cita.placas}',
      );
    }

    if (_clienteId == null) {
      return _aviso('Selecciona primero el cliente para ver sus vehículos.');
    }

    if (_cargandoVehiculos) {
      return _cargandoFila('Cargando vehículos del cliente…');
    }

    if (_errorVehiculos != null) {
      return _aviso(
        _errorVehiculos!,
        accionLabel: 'Reintentar',
        onAction: () => _cargarVehiculos(_clienteId!),
      );
    }

    if (_vehiculos.isEmpty) {
      return _aviso(
        'Este cliente todavía no tiene vehículos registrados. Registra un '
        'vehículo primero o elige otro cliente.',
      );
    }

    return DropdownButtonFormField<int>(
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
        for (final Vehicle vehiculo in _vehiculos)
          DropdownMenuItem<int>(
            value: vehiculo.id,
            child: Text(
              '${vehiculo.descripcion} ${vehiculo.anio} · ${vehiculo.placas}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: _saving ? null : _onVehiculoChanged,
      validator: (int? value) =>
          value == null ? 'Selecciona el vehículo de la cita.' : null,
    );
  }

  Widget _cargandoFila(String mensaje) {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: AppMetrics.spinnerSize,
          height: AppMetrics.spinnerSize,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(mensaje, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _aviso(
    String mensaje, {
    String? accionLabel,
    VoidCallback? onAction,
  }) {
    return AppPanel(
      expand: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(mensaje, style: Theme.of(context).textTheme.bodyMedium),
          if (accionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onAction,
              child: Text(accionLabel),
            ),
          ],
        ],
      ),
    );
  }
}
