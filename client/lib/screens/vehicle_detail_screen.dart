import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../providers/load_status.dart';
import '../providers/vehicles_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import 'client_detail_screen.dart';
import 'vehicle_form_screen.dart';

/// Argumento de la ruta de detalle de vehículo.
class VehicleDetailArgs {
  const VehicleDetailArgs({required this.vehicleId});

  final int vehicleId;
}

/// Ficha del vehículo con su propietario (FR-018, US5).
class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final int vehicleId;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late final VehiclesProvider _vehicles;

  @override
  void initState() {
    super.initState();
    _vehicles = context.read<VehiclesProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _vehicles.loadDetail(widget.vehicleId);
    });
  }

  Future<void> _goToEdit(Vehicle vehicle) async {
    final Object? result = await Navigator.pushNamed(
      context,
      Routes.vehicleEdit,
      arguments: VehicleFormArgs(vehicle: vehicle),
    );
    if (result == true && mounted) {
      _vehicles.loadDetail(widget.vehicleId);
    }
  }

  void _goToOwner(int clienteId) {
    Navigator.pushNamed(
      context,
      Routes.clientDetail,
      arguments: ClientDetailArgs(clientId: clienteId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final VehiclesProvider vehicles = context.watch<VehiclesProvider>();

    switch (vehicles.detailStatus) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando vehículo…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: vehicles.detailError ?? AppMessages.unexpectedError,
          onRetry: () => _vehicles.loadDetail(widget.vehicleId),
        );
      case LoadStatus.ready:
        final Vehicle? vehicle = vehicles.selected;
        if (vehicle == null) {
          return const ErrorView(mensaje: 'No se encontró el vehículo.');
        }
        return _buildContent(vehicle);
    }
  }

  Widget _buildContent(Vehicle vehicle) {
    final MotorixColors colors = context.motorixColors;
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
                    vehicle.descripcion,
                    style: textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _goToEdit(vehicle),
                  icon: const Icon(
                    LucideIcons.pencil,
                    size: AppMetrics.iconSizeSmall,
                  ),
                  label: const Text('Editar'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Datos del vehículo', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  DetailRow(label: 'Marca', value: vehicle.marca),
                  DetailRow(label: 'Modelo', value: vehicle.modelo),
                  DetailRow(label: 'Año', value: '${vehicle.anio}'),
                  DetailRow(label: 'Placas', value: vehicle.placas),
                  DetailRow(
                    label: 'VIN',
                    value: vehicle.vin ?? 'Sin VIN registrado',
                  ),
                  DetailRow(
                    label: 'Kilometraje',
                    value: Formatters.mileage(vehicle.kilometrajeActual),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Propietario', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  DetailRow(
                    label: 'Nombre',
                    value: vehicle.dueno,
                    onTap: () => _goToOwner(vehicle.clienteId),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Selecciona el nombre para abrir la ficha del cliente.',
                    style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
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
