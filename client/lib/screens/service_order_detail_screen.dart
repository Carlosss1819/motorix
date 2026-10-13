import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/service_order.dart';
import '../providers/auth_provider.dart';
import '../providers/load_status.dart';
import '../providers/service_orders_provider.dart';
import '../services/api_client.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/status_chip.dart';
import 'client_detail_screen.dart';
import 'vehicle_detail_screen.dart';

/// Argumento de la ruta de detalle de una orden.
class ServiceOrderDetailArgs {
  const ServiceOrderDetailArgs({required this.orderId});

  final int orderId;
}

/// Ficha de la orden de servicio con cliente, vehículo y estado (HU1,
/// escenario 3: cliente, vehículo, motivo, estado y fecha).
class ServiceOrderDetailScreen extends StatefulWidget {
  const ServiceOrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<ServiceOrderDetailScreen> createState() =>
      _ServiceOrderDetailScreenState();
}

class _ServiceOrderDetailScreenState extends State<ServiceOrderDetailScreen> {
  late final ServiceOrdersProvider _orders;

  /// El selector de asignación es de recepción/administración (FR-009); el
  /// mecánico solo consulta su orden.
  late final bool _esMecanico;

  List<MechanicOption> _mecanicos = const <MechanicOption>[];
  bool _cargandoMecanicos = false;
  String? _errorMecanicos;
  bool _guardandoAsignacion = false;

  @override
  void initState() {
    super.initState();
    _orders = context.read<ServiceOrdersProvider>();
    _esMecanico = context.read<AuthProvider>().user?.rol == Rol.mechanic;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _orders.loadDetail(widget.orderId);
      if (!_esMecanico) {
        _cargarMecanicos();
      }
    });
  }

  Future<void> _cargarMecanicos() async {
    setState(() {
      _cargandoMecanicos = true;
      _errorMecanicos = null;
    });
    try {
      final List<MechanicOption> lista = await _orders.loadMechanics();
      if (!mounted) {
        return;
      }
      setState(() {
        _mecanicos = lista;
        _cargandoMecanicos = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMecanicos = e.mensaje;
        _cargandoMecanicos = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMecanicos = AppMessages.unexpectedError;
        _cargandoMecanicos = false;
      });
    }
  }

  /// Asigna o desasigna con confirmación previa (Principio VIII). El `409` del
  /// backend se muestra tal cual, explicando por qué no se pudo (FR-009).
  Future<void> _asignar(ServiceOrder order, int? mecanicoId) async {
    final bool confirmado = await showConfirmDialog(
      context,
      titulo:
          mecanicoId == null ? 'Desasignar mecánico' : 'Asignar mecánico',
      mensaje: mecanicoId == null
          ? 'La orden #${order.id} quedará sin mecánico asignado. ¿Continuar?'
          : 'Asignar la orden #${order.id} al mecánico elegido. Podrás '
              'reasignarla mientras no esté cerrada. ¿Continuar?',
      destructive: mecanicoId == null,
    );
    if (!confirmado || !mounted) {
      return;
    }

    setState(() => _guardandoAsignacion = true);
    try {
      await _orders.assign(id: order.id, mecanicoId: mecanicoId);
      if (!mounted) {
        return;
      }
      setState(() => _guardandoAsignacion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mecanicoId == null
                ? 'Mecánico desasignado correctamente.'
                : 'Mecánico asignado correctamente.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _guardandoAsignacion = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje)),
      );
    }
  }

  /// Panel de asignación (US3/FR-009): oculto para el mecánico y para las
  /// órdenes cerradas, donde el backend responde `409`.
  Widget _buildAsignacion(ServiceOrder order) {
    if (_esMecanico || !order.editable) {
      return const SizedBox.shrink();
    }
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Asignación de mecánico', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (_errorMecanicos != null)
            Text(
              _errorMecanicos!,
              style: textTheme.bodySmall?.copyWith(color: colors.danger),
            )
          else if (_cargandoMecanicos)
            const SizedBox(
              width: AppMetrics.spinnerSize,
              height: AppMetrics.spinnerSize,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            DropdownButtonFormField<int?>(
              // La clave reinicia el selector cuando cambia la asignación.
              key: ValueKey<String>('mecanico-${order.mecanicoId}'),
              initialValue: order.mecanicoId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Mecánico asignado',
                prefixIcon: Icon(
                  LucideIcons.userRound,
                  size: AppMetrics.iconSizeSmall,
                ),
              ),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Sin asignar'),
                ),
                // El mecánico actual puede estar inactivo: se muestra igual.
                if (order.mecanicoId != null &&
                    !_mecanicos.any(
                      (MechanicOption m) => m.id == order.mecanicoId,
                    ))
                  DropdownMenuItem<int?>(
                    value: order.mecanicoId,
                    child: Text(order.mecanico ?? ''),
                  ),
                for (final MechanicOption mechanic in _mecanicos)
                  DropdownMenuItem<int?>(
                    value: mechanic.id,
                    child: Text(mechanic.username),
                  ),
              ],
              onChanged: _guardandoAsignacion
                  ? null
                  : (int? value) {
                      if (value == order.mecanicoId) {
                        return;
                      }
                      _asignar(order, value);
                    },
            ),
        ],
      ),
    );
  }

  void _goToClient(int clienteId) {
    Navigator.pushNamed(
      context,
      Routes.clientDetail,
      arguments: ClientDetailArgs(clientId: clienteId),
    );
  }

  void _goToVehicle(int vehiculoId) {
    Navigator.pushNamed(
      context,
      Routes.vehicleDetail,
      arguments: VehicleDetailArgs(vehicleId: vehiculoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ServiceOrdersProvider orders =
        context.watch<ServiceOrdersProvider>();

    switch (orders.detailStatus) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando orden…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: orders.detailError ?? AppMessages.unexpectedError,
          onRetry: () => _orders.loadDetail(widget.orderId),
        );
      case LoadStatus.ready:
        final ServiceOrder? order = orders.selected;
        if (order == null) {
          return const ErrorView(mensaje: 'No se encontró la orden.');
        }
        return _buildContent(order);
    }
  }

  Widget _buildContent(ServiceOrder order) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const BackAction(),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Orden #${order.id}',
                    style: textTheme.titleLarge,
                  ),
                ),
                OrderStatusChip(estado: order.estado),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Datos de la orden', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  DetailRow(label: 'Estado', value: orderStatusLabel(order.estado)),
                  DetailRow(label: 'Motivo de visita', value: order.motivoVisita),
                  DetailRow(
                    label: 'Fecha de ingreso',
                    value: Formatters.date(order.fechaIngreso),
                  ),
                  DetailRow(
                    label: 'Kilometraje',
                    value: Formatters.mileage(order.kilometrajeEntrada),
                  ),
                  DetailRow(
                    label: 'Mecánico',
                    value: order.mecanico ?? 'Sin asignar',
                  ),
                  if (order.fechaEntrega != null) ...<Widget>[
                    DetailRow(
                      label: 'Fecha de entrega',
                      value: Formatters.date(order.fechaEntrega),
                    ),
                  ],
                  if (order.notaCorreccionKilometraje.isNotEmpty) ...<Widget>[
                    DetailRow(
                      label: 'Corrección de kilometraje',
                      value: order.notaCorreccionKilometraje,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!_esMecanico && order.editable) ...<Widget>[
              _buildAsignacion(order),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Cliente', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  DetailRow(
                    label: 'Nombre',
                    value: order.cliente,
                    onTap: () => _goToClient(order.clienteId),
                  ),
                  DetailRow(
                    label: 'Teléfono',
                    value:
                        order.telefono.isEmpty
                            ? 'Sin teléfono registrado'
                            : order.telefono,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Vehículo', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  DetailRow(
                    label: 'Vehículo',
                    value: order.vehiculo,
                    onTap: () => _goToVehicle(order.vehiculoId),
                  ),
                  DetailRow(label: 'Placas', value: order.placas),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Selecciona el nombre del cliente o el vehículo para abrir su '
              'ficha.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
