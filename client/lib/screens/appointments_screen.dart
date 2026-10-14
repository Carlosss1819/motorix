import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../providers/appointments_provider.dart';
import '../providers/load_status.dart';
import '../providers/shell_provider.dart';
import '../services/api_client.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/app_table.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/status_chip.dart';
import 'appointment_form_screen.dart';
import 'service_order_form_screen.dart';

/// Lista de citas de recepción (US2/HU2): listado filtrado por día, con
/// filtro de estado, búsqueda por placas o nombre del cliente y las acciones
/// **Cancelar** y **Recibir** con confirmación (Principio VIII).
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late final ShellProvider _shell;
  late final AppointmentsProvider _citas;
  late final TextEditingController _fechaController;
  String _lastQuery = '';
  String _estado = kSinEstadoCita;

  @override
  void initState() {
    super.initState();
    _shell = context.read<ShellProvider>();
    _citas = context.read<AppointmentsProvider>();
    _fechaController = TextEditingController(text: _citas.fecha);
    _lastQuery = _shell.queryFor(SearchHints.appointments);
    _estado = _citas.estado;
    _shell.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_lastQuery.isNotEmpty) {
        _citas.setBuscar(_lastQuery);
      } else if (_citas.status == LoadStatus.idle) {
        _citas.load();
      }
    });
  }

  void _onSearchChanged() {
    final String query = _shell.queryFor(SearchHints.appointments);
    if (query == _lastQuery) {
      return;
    }
    _lastQuery = query;
    _citas.setBuscar(query);
  }

  @override
  void dispose() {
    _shell.removeListener(_onSearchChanged);
    _fechaController.dispose();
    super.dispose();
  }

  void _goToNew() async {
    // Sin el parámetro <bool> a propósito: `onGenerateRoute` devuelve una
    // ruta `Route<dynamic>` y el cast a `Route<bool>` revienta `pushNamed`
    // en tiempo de ejecución (la navegación moriría en silencio).
    final Object? creado = await Navigator.pushNamed(
      context,
      Routes.appointmentNew,
    );
    if (creado == true && mounted) {
      _citas.load();
    }
  }

  void _goToEdit(Appointment cita) async {
    // Sin <bool>: el cast de la ruta generada fallaría (ver `_goToNew`).
    final Object? editada = await Navigator.pushNamed(
      context,
      Routes.appointmentEdit,
      arguments: AppointmentFormArgs(cita: cita),
    );
    if (editada == true && mounted) {
      _citas.load();
    }
  }

  /// Abre el selector de día; vacío significa "todas las fechas".
  Future<void> _elegirFecha() async {
    final DateTime? actual = _citas.fecha.isEmpty
        ? null
        : DateTime.tryParse(_citas.fecha);
    final DateTime? seleccionada = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (seleccionada == null || !mounted) {
      return;
    }
    final String iso = _fechaToIso(seleccionada);
    _fechaController.text = iso;
    _citas.setFecha(iso);
  }

  void _limpiarFecha() {
    _fechaController.text = '';
    _citas.setFecha(kSinFechaCita);
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Cancelación con confirmación y motivo opcional (FR-006).
  Future<void> _cancelar(Appointment cita) async {
    final String? motivo = await showAppDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _CancelAppointmentDialog(cita: cita),
    );
    if (motivo == null || !mounted) {
      return;
    }
    try {
      await _citas.cancel(id: cita.id, motivo: motivo);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita cancelada correctamente.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        _mostrarError(e.mensaje);
      }
    } catch (_) {
      if (mounted) {
        _mostrarError(AppMessages.unexpectedError);
      }
    }
  }

  /// Recepción con confirmación (FR-007): al recibirla se ofrece continuar
  /// con el formulario de orden usando la precarga del backend.
  Future<void> _recibir(Appointment cita) async {
    final bool ok = await showConfirmDialog(
      context,
      titulo: 'Recibir cita',
      mensaje: '¿Confirmar la recepción de la cita de ${cita.cliente} del '
          '${Formatters.date(cita.fecha)} a las ${cita.hora}?',
      confirmarLabel: 'Recibir',
    );
    if (!ok || !mounted) {
      return;
    }

    final ReceivedAppointment recibida;
    try {
      recibida = await _citas.receive(id: cita.id);
    } on ApiException catch (e) {
      if (mounted) {
        _mostrarError(e.mensaje);
      }
      return;
    } catch (_) {
      if (mounted) {
        _mostrarError(AppMessages.unexpectedError);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cita recibida correctamente.')),
    );

    final bool crearOrden = await showConfirmDialog(
      context,
      titulo: 'Cita recibida',
      mensaje: '¿Crear la orden de servicio ahora con los datos de la cita?',
      confirmarLabel: 'Crear orden',
      cancelarLabel: 'Ahora no',
    );
    if (!crearOrden || !mounted) {
      return;
    }
    Navigator.pushNamed(
      context,
      Routes.serviceOrderNew,
      arguments: ServiceOrderFormArgs(citaRecibida: recibida),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppointmentsProvider citas = context.watch<AppointmentsProvider>();
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _goToNew,
                icon: const Icon(
                  LucideIcons.plus,
                  size: AppMetrics.iconSizeSmall,
                ),
                label: const Text('Nueva cita'),
              ),
              const SizedBox(width: AppSpacing.lg),
              _buildFechaField(citas),
              const SizedBox(width: AppSpacing.lg),
              _buildEstadoFilter(citas),
              const Spacer(),
              Text(_counterText(citas), style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _buildBody(citas)),
          if (citas.status == LoadStatus.ready && citas.total > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _buildPagination(citas),
          ],
        ],
      ),
    );
  }

  String _counterText(AppointmentsProvider citas) {
    if (citas.status != LoadStatus.ready) {
      return '';
    }
    final int total = citas.total;
    return total == 1 ? '1 cita' : '$total citas';
  }

  /// Selector de día del listado (HU2); con el icono de limpiar vuelve a
  /// "todas las fechas".
  Widget _buildFechaField(AppointmentsProvider citas) {
    return SizedBox(
      width: AppMetrics.comboboxWidth,
      child: TextFormField(
        controller: _fechaController,
        readOnly: true,
        onTap: _elegirFecha,
        decoration: InputDecoration(
          labelText: 'Fecha',
          hintText: 'Todas las fechas',
          prefixIcon: const Icon(
            LucideIcons.calendar,
            size: AppMetrics.iconSizeSmall,
          ),
          suffixIcon: citas.fecha.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Ver todas las fechas',
                  onPressed: _limpiarFecha,
                  icon: const Icon(
                    LucideIcons.x,
                    size: AppMetrics.iconSizeSmall,
                  ),
                ),
        ),
      ),
    );
  }

  /// Selector de estado de cita (FR-006).
  Widget _buildEstadoFilter(AppointmentsProvider citas) {
    return SizedBox(
      width: AppMetrics.comboboxWidth,
      child: DropdownButtonFormField<String>(
        initialValue: _estado,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Estado',
          prefixIcon: Icon(
            LucideIcons.listFilter,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(
            value: kSinEstadoCita,
            child: Text('Todos los estados'),
          ),
          for (final String estado in appointmentStatusValues)
            DropdownMenuItem<String>(
              value: estado,
              child: Text(orderStatusLabel(estado)),
            ),
        ],
        onChanged: (String? value) {
          if (value == null) {
            return;
          }
          setState(() => _estado = value);
          _citas.setEstado(value);
        },
      ),
    );
  }

  Widget _buildBody(AppointmentsProvider citas) {
    switch (citas.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando citas…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: citas.error ?? AppMessages.unexpectedError,
          onRetry: _citas.reload,
        );
      case LoadStatus.ready:
        if (citas.items.isEmpty) {
          return EmptyView(
            mensaje: _emptyMessage(citas),
            actionLabel: 'Nueva cita',
            onAction: _goToNew,
          );
        }
        return _buildTable(citas.items);
    }
  }

  String _emptyMessage(AppointmentsProvider citas) {
    if (_lastQuery.isNotEmpty) {
      return 'No se encontraron citas que coincidan con "$_lastQuery".';
    }
    if (_estado != kSinEstadoCita) {
      return 'No hay citas en estado ${orderStatusLabel(_estado)}.';
    }
    if (citas.fecha.isNotEmpty) {
      return 'No hay citas para el ${Formatters.date(citas.fecha)}.';
    }
    return 'No hay citas registradas. Crea la primera para empezar.';
  }

  Widget _buildTable(List<Appointment> items) {
    final MotorixColors colors = context.motorixColors;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: FullWidthTable(
        columns: <DataColumn>[
          fluidColumn('Hora', weight: 1, minWidth: 110),
          fluidColumn('Cliente', weight: 1.6, minWidth: 140),
          fluidColumn('Vehículo', weight: 1.6, minWidth: 150),
          fluidColumn('Motivo', weight: 1.8, minWidth: 150),
          fluidColumn('Estado', weight: 1, minWidth: 110),
          fluidColumn('Acciones', weight: 1.8, minWidth: 180),
        ],
        rows: <DataRow>[
          for (final Appointment cita in items) _buildRow(cita, colors),
        ],
      ),
    );
  }

  DataRow _buildRow(Appointment cita, MotorixColors colors) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.hovered) ? colors.primarySoft : null,
      ),
      cells: <DataCell>[
        DataCell(Text(cita.hora)),
        DataCell(Text(cita.cliente, overflow: TextOverflow.ellipsis)),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                cita.vehiculo,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
              Text(
                cita.placas,
                style: textTheme.labelSmall
                    ?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        DataCell(Text(cita.motivo, overflow: TextOverflow.ellipsis)),
        DataCell(AppointmentStatusChip(estado: cita.estado)),
        DataCell(_buildActions(cita)),
      ],
    );
  }

  /// Acciones por cita: editar siempre que esté `PROGRAMADA`, y recibir o
  /// cancelar solo en ese mismo estado (FR-006).
  Widget _buildActions(Appointment cita) {
    if (!cita.programada) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: 'Editar cita',
          onPressed: () => _goToEdit(cita),
          icon: const Icon(
            LucideIcons.pencil,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
        TextButton(
          onPressed: () => _recibir(cita),
          child: const Text('Recibir'),
        ),
        TextButton(
          onPressed: () => _cancelar(cita),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildPagination(AppointmentsProvider citas) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Text(
          'Mostrando ${citas.items.length} de ${citas.total}',
          style: textTheme.bodySmall,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Página anterior',
          onPressed:
              citas.pagina > 1 ? () => _citas.goToPage(citas.pagina - 1) : null,
          icon: const Icon(
            LucideIcons.chevronLeft,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Página ${citas.pagina} de ${citas.paginas}',
            style: textTheme.bodySmall,
          ),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: citas.pagina < citas.paginas
              ? () => _citas.goToPage(citas.pagina + 1)
              : null,
          icon: const Icon(
            LucideIcons.chevronRight,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
      ],
    );
  }
}

/// Formatea una fecha local a `AAAA-MM-DD`.
String _fechaToIso(DateTime fecha) {
  final String anio = fecha.year.toString().padLeft(4, '0');
  final String mes = fecha.month.toString().padLeft(2, '0');
  final String dia = fecha.day.toString().padLeft(2, '0');
  return '$anio-$mes-$dia';
}

/// Diálogo de cancelación con motivo opcional (FR-006, aclaración del
/// 2026-10-11). Devuelve `null` cuando el usuario decide no cancelar.
class _CancelAppointmentDialog extends StatefulWidget {
  const _CancelAppointmentDialog({required this.cita});

  final Appointment cita;

  @override
  State<_CancelAppointmentDialog> createState() =>
      _CancelAppointmentDialogState();
}

class _CancelAppointmentDialogState extends State<_CancelAppointmentDialog> {
  late final TextEditingController _motivoController;

  @override
  void initState() {
    super.initState();
    _motivoController = TextEditingController();
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final Appointment cita = widget.cita;

    return AlertDialog(
      title: const Text('Cancelar cita'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '¿Seguro que quieres cancelar la cita de ${cita.cliente} del '
            '${Formatters.date(cita.fecha)} a las ${cita.hora}?',
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _motivoController,
            autofocus: true,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Ej. El cliente no pudo asistir',
              counterText: '',
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop<String>(null),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.danger,
            foregroundColor: colors.surface,
          ),
          onPressed: () =>
              Navigator.of(context).pop<String>(_motivoController.text.trim()),
          child: const Text('Cancelar cita'),
        ),
      ],
    );
  }
}
