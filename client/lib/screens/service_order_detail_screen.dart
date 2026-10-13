import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_order.dart';
import '../providers/load_status.dart';
import '../providers/service_orders_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
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

  @override
  void initState() {
    super.initState();
    _orders = context.read<ServiceOrdersProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _orders.loadDetail(widget.orderId);
    });
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
