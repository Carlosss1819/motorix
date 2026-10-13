import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/client.dart';
import '../models/vehicle.dart';
import '../providers/clients_provider.dart';
import '../providers/load_status.dart';
import '../providers/service_orders_provider.dart';
import '../providers/vehicles_provider.dart';
import '../services/api_client.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../utils/validators.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';
import 'vehicle_form_screen.dart';

/// Argumento de la ruta de nueva orden de servicio.
class ServiceOrderFormArgs {
  const ServiceOrderFormArgs({this.citaRecibida});

  /// Precarga devuelta al recibir una cita (FR-007): cliente, vehículo,
  /// motivo y la cita de origen que se enviará en el alta.
  final ReceivedAppointment? citaRecibida;
}

/// Formulario de nueva orden de servicio (US1/HU1; la US2 lo amplía con la
/// precarga de una cita recibida, FR-007).
///
/// La orden se crea con cliente y vehículo existentes (RN‑01, RN‑02), motivo
/// de visita obligatorio, fecha de ingreso y kilometraje; nace en estado
/// `RECIBIDO` y el backend valida el kilometraje contra la última orden del
/// vehículo (FR‑018).
class ServiceOrderFormScreen extends StatefulWidget {
  const ServiceOrderFormScreen({super.key, this.cita});

  /// Si se pasa una cita recibida, el formulario arranca precargado con ella
  /// y envía su `citaId` en el alta (FR-007).
  final ReceivedAppointment? cita;

  @override
  State<ServiceOrderFormScreen> createState() =>
      _ServiceOrderFormScreenState();
}

class _ServiceOrderFormScreenState extends State<ServiceOrderFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _motivoController;
  late final TextEditingController _fechaController;
  late final TextEditingController _kilometrajeController;

  int? _clienteId;
  int? _vehiculoId;

  /// Valor de kilometraje que se sugirió automáticamente, para no pisar una
  /// corrección hecha a mano por el usuario.
  String? _kilometrajeSugerido;

  List<Vehicle> _vehiculos = const <Vehicle>[];
  bool _cargandoVehiculos = false;
  String? _errorVehiculos;

  String _error = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _motivoController = TextEditingController();
    _fechaController = TextEditingController(text: _hoyIso());
    _kilometrajeController = TextEditingController();

    // Precarga desde una cita RECIBIDA (FR-007): cliente y motivo llegan de
    // la cita; el vehículo se confirma al cargar la lista del cliente para no
    // pintar el selector con un valor que aún no está en sus ítems.
    final ReceivedAppointment? cita = widget.cita;
    if (cita != null) {
      _clienteId = cita.clienteId;
      _motivoController.text = cita.motivo;
      _cargandoVehiculos = true;
    }

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
        _cargarVehiculos(_clienteId!, preseleccionado: widget.cita?.vehiculoId);
      });
    }
  }

  @override
  void dispose() {
    _motivoController.dispose();
    _fechaController.dispose();
    _kilometrajeController.dispose();
    super.dispose();
  }

  /// Fecha local en formato `AAAA-MM-DD` (el que exige el backend).
  String _hoyIso() {
    final DateTime hoy = DateTime.now();
    final String anio = hoy.year.toString().padLeft(4, '0');
    final String mes = hoy.month.toString().padLeft(2, '0');
    final String dia = hoy.day.toString().padLeft(2, '0');
    return '$anio-$mes-$dia';
  }

  bool get _dirty =>
      _motivoController.text.isNotEmpty ||
      _kilometrajeController.text.isNotEmpty ||
      _clienteId != null ||
      _fechaController.text != _hoyIso();

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
  /// aún no tiene ninguno registrado (escenario 5 HU1).
  Future<void> _cargarVehiculos(int clienteId, {int? preseleccionado}) async {
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
      // Vehículo de la cita precargada, solo si está en la lista del cliente.
      if (preseleccionado != null &&
          _vehiculos.any((Vehicle v) => v.id == preseleccionado)) {
        _vehiculoId = preseleccionado;
      }
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
    final Vehicle elegido = _vehiculos[indice];
    setState(() {
      _vehiculoId = vehiculoId;
      // Se sugiere el kilometraje actual del vehículo, sin pisar lo que el
      // usuario haya escrito a mano.
      final String actual = _kilometrajeController.text;
      if (actual.isEmpty || actual == _kilometrajeSugerido) {
        _kilometrajeController.text = '${elegido.kilometrajeActual}';
        _kilometrajeSugerido = '${elegido.kilometrajeActual}';
      }
    });
  }

  String? _validarFecha(String? value) {
    final String texto = value?.trim() ?? '';
    if (texto.isEmpty) {
      return 'Escribe la fecha de ingreso.';
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) {
      return 'La fecha de ingreso debe tener el formato AAAA-MM-DD.';
    }
    final DateTime? fecha = DateTime.tryParse(texto);
    if (fecha == null || fecha.toIso8601String().substring(0, 10) != texto) {
      return 'Escribe una fecha de ingreso válida.';
    }
    return null;
  }

  String? _validarMotivo(String? value) {
    final String? requerido = Validators.required(value, 'el motivo de visita');
    if (requerido != null) {
      return 'Escribe el motivo de la visita.';
    }
    if (value!.trim().length > 255) {
      return 'El motivo de visita no puede exceder 255 caracteres.';
    }
    return null;
  }

  /// Aviso de que la orden deriva de una cita recibida (FR-007).
  Widget _buildCitaOrigenInfo() {
    final ReceivedAppointment cita = widget.cita!;
    return AppPanel(
      expand: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        'Orden derivada de la cita #${cita.citaId}: cliente, vehículo y '
        'motivo precargados desde la cita recibida.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Future<void> _save() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (_cargandoVehiculos || _vehiculoId == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    final ServiceOrdersProvider ordenes = context.read<ServiceOrdersProvider>();
    try {
      await ordenes.create(
        clienteId: _clienteId!,
        vehiculoId: _vehiculoId!,
        motivoVisita: _motivoController.text.trim(),
        fechaIngreso: _fechaController.text.trim(),
        kilometraje: int.parse(_kilometrajeController.text.trim()),
        // Cita de origen cuando la orden arranca desde una cita recibida
        // (FR-007); el backend valida que siga RECIBIDA y sin usar.
        citaId: widget.cita?.citaOrigen,
      );

      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Orden de servicio registrada correctamente.'),
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
              Text('Registrar orden', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Selecciona el cliente y el vehículo, escribe el motivo de la '
                'visita y confirma el kilometraje de entrada. La orden nace '
                'en estado Recibido.',
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
                      if (widget.cita != null) ...<Widget>[
                        _buildCitaOrigenInfo(),
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
                              controller: _motivoController,
                              enabled: !_saving,
                              textCapitalization:
                                  TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Motivo de visita *',
                                hintText: 'Ej. Revisión de frenos',
                                prefixIcon: Icon(
                                  LucideIcons.clipboardList,
                                  size: AppMetrics.iconSizeSmall,
                                ),
                              ),
                              validator: _validarMotivo,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: TextFormField(
                              controller: _fechaController,
                              enabled: !_saving,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: 'Fecha de ingreso *',
                                hintText: 'AAAA-MM-DD',
                                prefixIcon: Icon(
                                  LucideIcons.calendar,
                                  size: AppMetrics.iconSizeSmall,
                                ),
                              ),
                              validator: _validarFecha,
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
                              controller: _kilometrajeController,
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Kilometraje de entrada *',
                                hintText: 'Ej. 45200',
                                prefixIcon: Icon(
                                  LucideIcons.gauge,
                                  size: AppMetrics.iconSizeSmall,
                                ),
                              ),
                              validator: Validators.mileage,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FormActions(
                        onCancel: _confirmExit,
                        onSave: _save,
                        saveLabel: 'Registrar orden',
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

  Widget _buildClienteField(ClientsProvider clients) {
    if (clients.items.isEmpty && clients.status == LoadStatus.loading) {
      return _cargandoFila('Cargando clientes…');
    }

    if (clients.items.isEmpty) {
      final bool hayError = clients.status == LoadStatus.error;
      return _aviso(
        hayError
            ? clients.error ?? AppMessages.unexpectedError
            : 'No hay clientes registrados todavía. Da de alta un cliente '
                  'antes de registrar una orden.',
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
          value == null ? 'Selecciona el cliente de la orden.' : null,
    );
  }

  /// Selector de vehículos del cliente elegido. Un cliente sin vehículos no
  /// puede generar una orden huérfana (escenario 5 HU1).
  Widget _buildVehiculoField() {
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
        accionLabel: 'Registrar vehículo',
        onAction: () => Navigator.pushNamed(
          context,
          Routes.vehicleNew,
          arguments: VehicleFormArgs(clienteId: _clienteId),
        ),
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
          value == null ? 'Selecciona el vehículo de la orden.' : null,
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
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(
                LucideIcons.plus,
                size: AppMetrics.iconSizeSmall,
              ),
              label: Text(accionLabel),
            ),
          ],
        ],
      ),
    );
  }
}
