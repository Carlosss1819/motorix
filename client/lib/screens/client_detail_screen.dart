import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../models/vehicle.dart';
import '../providers/clients_provider.dart';
import '../providers/load_status.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import 'client_form_screen.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';

/// Argumento de la ruta de detalle de cliente.
class ClientDetailArgs {
  const ClientDetailArgs({required this.clientId});

  final int clientId;
}

/// Ficha del cliente con sus vehículos asociados (FR-014, US3).
class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final int clientId;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late final ClientsProvider _clients;

  @override
  void initState() {
    super.initState();
    _clients = context.read<ClientsProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _clients.loadDetail(widget.clientId);
    });
  }

  Future<void> _goToEdit(Client client) async {
    final Object? result = await Navigator.pushNamed(
      context,
      Routes.clientEdit,
      arguments: ClientFormArgs(client: client),
    );
    if (result == true && mounted) {
      _clients.loadDetail(widget.clientId);
    }
  }

  Future<void> _goToNewVehicle(int? clienteId) async {
    final Object? result = await Navigator.pushNamed(
      context,
      Routes.vehicleNew,
      arguments: VehicleFormArgs(clienteId: clienteId),
    );
    if (result == true && mounted) {
      _clients.loadDetail(widget.clientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClientsProvider clients = context.watch<ClientsProvider>();

    switch (clients.detailStatus) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando cliente…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: clients.detailError ?? AppMessages.unexpectedError,
          onRetry: () => _clients.loadDetail(widget.clientId),
        );
      case LoadStatus.ready:
        final Client? client = clients.selected;
        if (client == null) {
          return const ErrorView(mensaje: 'No se encontró el cliente.');
        }
        return _buildContent(client);
    }
  }

  Widget _buildContent(Client client) {
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
                    client.nombre,
                    style: textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _goToEdit(client),
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
                  Text('Datos del cliente', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  DetailRow(label: 'Nombre', value: client.nombre),
                  DetailRow(label: 'Teléfono', value: client.telefono),
                  DetailRow(
                    label: 'Correo',
                    value: client.email ?? 'Sin correo registrado',
                  ),
                  DetailRow(
                    label: 'Fecha de registro',
                    value: Formatters.date(client.fechaRegistro),
                  ),
                  DetailRow(label: 'Estado', value: client.estadoLabel),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Vehículos asociados',
                          style: textTheme.titleMedium,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _goToNewVehicle(client.id),
                        icon: const Icon(
                          LucideIcons.plus,
                          size: AppMetrics.iconSizeSmall,
                        ),
                        label: const Text('Registrar vehículo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (client.vehiculos.isEmpty)
                    _EmptyVehicles(onAction: () => _goToNewVehicle(client.id))
                  else
                    _VehicleList(
                      vehiculos: client.vehiculos,
                      onTap: (VehicleSummary vehiculo) {
                        Navigator.pushNamed(
                          context,
                          Routes.vehicleDetail,
                          arguments: VehicleDetailArgs(vehicleId: vehiculo.id),
                        );
                      },
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

class _VehicleList extends StatelessWidget {
  const _VehicleList({required this.vehiculos, required this.onTap});

  final List<VehicleSummary> vehiculos;
  final ValueChanged<VehicleSummary> onTap;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < vehiculos.length; index++) ...<Widget>[
          if (index > 0) const Divider(),
          InkWell(
            onTap: () => onTap(vehiculos[index]),
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Icon(
                    LucideIcons.carFront,
                    size: AppMetrics.iconSize,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          vehiculos[index].descripcion,
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${vehiculos[index].placas} · '
                          '${vehiculos[index].anio}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: AppMetrics.iconSizeSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyVehicles extends StatelessWidget {
  const _EmptyVehicles({required this.onAction});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'Sin vehículos registrados',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Registra el primer vehículo de este cliente para asociarlo a su '
            'ficha.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onAction,
            icon: const Icon(
              LucideIcons.plus,
              size: AppMetrics.iconSizeSmall,
            ),
            label: const Text('Registrar vehículo'),
          ),
        ],
      ),
    );
  }
}
