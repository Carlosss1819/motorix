import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../models/service_order.dart';
import '../providers/appointments_provider.dart';
import '../providers/load_status.dart';
import '../providers/service_orders_provider.dart';
import '../services/api_client.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import '../widgets/status_chip.dart';

/// Panel de recepción (US6, R-09): las citas del día y las órdenes abiertas
/// del taller en una sola vista, para planificar el trabajo sin abrir cada
/// registro (escenarios de la HU6).
///
/// Es la vista principal ("Inicio") de recepción y administración. No toca
/// los filtros de las pantallas de citas y de órdenes: consulta cada fuente
/// con su propio servicio.
class ReceptionScreen extends StatefulWidget {
  const ReceptionScreen({super.key});

  @override
  State<ReceptionScreen> createState() => _ReceptionScreenState();
}

class _ReceptionScreenState extends State<ReceptionScreen> {
  late final AppointmentsProvider _citas;
  late final ServiceOrdersProvider _ordenes;

  LoadStatus _estadoCitas = LoadStatus.idle;
  LoadStatus _estadoOrdenes = LoadStatus.idle;
  List<Appointment> _citasDelDia = const <Appointment>[];
  List<ServiceOrder> _ordenesAbiertas = const <ServiceOrder>[];
  String? _errorCitas;
  String? _errorOrdenes;

  @override
  void initState() {
    super.initState();
    _citas = context.read<AppointmentsProvider>();
    _ordenes = context.read<ServiceOrdersProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cargar();
      }
    });
  }

  /// Consulta las dos fuentes del panel en paralelo (R-09) y maneja por
  /// separado sus estados de carga y de error.
  Future<void> _cargar() async {
    setState(() {
      _estadoCitas = LoadStatus.loading;
      _estadoOrdenes = LoadStatus.loading;
      _errorCitas = null;
      _errorOrdenes = null;
    });
    await Future.wait(<Future<void>>[_cargarCitas(), _cargarOrdenes()]);
  }

  Future<void> _cargarCitas() async {
    try {
      final List<Appointment> lista = await _citas.listDay(hoyIso());
      if (!mounted) {
        return;
      }
      setState(() {
        _citasDelDia = lista;
        _estadoCitas = LoadStatus.ready;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorCitas = e.mensaje;
        _estadoCitas = LoadStatus.error;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorCitas = AppMessages.unexpectedError;
        _estadoCitas = LoadStatus.error;
      });
    }
  }

  Future<void> _cargarOrdenes() async {
    try {
      final List<ServiceOrder> lista = await _ordenes.listOpen();
      if (!mounted) {
        return;
      }
      setState(() {
        _ordenesAbiertas = lista;
        _estadoOrdenes = LoadStatus.ready;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorOrdenes = e.mensaje;
        _estadoOrdenes = LoadStatus.error;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorOrdenes = AppMessages.unexpectedError;
        _estadoOrdenes = LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool listo =
        _estadoCitas == LoadStatus.ready && _estadoOrdenes == LoadStatus.ready;
    final bool sinActividades = listo &&
        _citasDelDia.isEmpty &&
        _ordenesAbiertas.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Panel de recepción', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Citas de hoy (${Formatters.date(hoyIso())}) y órdenes abiertas '
              'del taller en una sola vista.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (sinActividades)
              _panelSinActividades()
            else ...<Widget>[
              _panelCitas(),
              const SizedBox(height: AppSpacing.lg),
              _panelOrdenes(),
            ],
          ],
        ),
      ),
    );
  }

  /// Estado vacío del panel (HU6, escenario 3): un día sin citas ni órdenes
  /// abiertas no es un error.
  Widget _panelSinActividades() {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Sin actividades por hoy: no hay citas ni órdenes abiertas.',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Las citas del día y las órdenes que siguen en el taller '
            'aparecerán aquí.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Panel de citas del día (HU6, escenario 1): hora, cliente, vehículo y
  /// estado de cada cita.
  Widget _panelCitas() {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Citas de hoy', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (_estadoCitas == LoadStatus.loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_estadoCitas == LoadStatus.error)
            _bloqueError(_errorCitas)
          else if (_citasDelDia.isEmpty)
            Text('Sin citas para hoy.', style: textTheme.bodySmall)
          else
            for (final Appointment cita in _citasDelDia)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${cita.hora} · ${cita.cliente}',
                            style: textTheme.bodyMedium,
                          ),
                          Text(
                            '${cita.vehiculo} · ${cita.placas}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OrderStatusChip(estado: cita.estado),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// Panel de órdenes abiertas (HU6, escenario 2): estado y mecánico
  /// asignado de cada orden que sigue en el taller.
  Widget _panelOrdenes() {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Órdenes abiertas', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (_estadoOrdenes == LoadStatus.loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_estadoOrdenes == LoadStatus.error)
            _bloqueError(_errorOrdenes)
          else if (_ordenesAbiertas.isEmpty)
            Text('Sin órdenes abiertas.', style: textTheme.bodySmall)
          else
            for (final ServiceOrder orden in _ordenesAbiertas)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '#${orden.id} · ${orden.motivoVisita}',
                            style: textTheme.bodyMedium,
                          ),
                          Text(
                            '${orden.vehiculo} · ${orden.placas}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        OrderStatusChip(estado: orden.estado),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          orden.mecanico ?? 'Sin asignar',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// Error de una fuente, con reintento; la otra fuente sigue visible.
  Widget _bloqueError(String? mensaje) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          mensaje ?? AppMessages.unexpectedError,
          style: textTheme.bodyMedium?.copyWith(color: colors.danger),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _cargar,
            child: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }
}
