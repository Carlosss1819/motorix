import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../providers/load_status.dart';
import '../providers/shell_provider.dart';
import '../providers/vehicles_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import 'vehicle_detail_screen.dart';
import 'vehicle_form_screen.dart';

/// Lista de vehículos (US5): búsqueda por placas, marca, modelo o propietario.
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  late final ShellProvider _shell;
  late final VehiclesProvider _vehicles;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _shell = context.read<ShellProvider>();
    _vehicles = context.read<VehiclesProvider>();
    _lastQuery = _shell.queryFor(SearchHints.vehicles);
    _shell.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _vehicles.load(buscar: _lastQuery);
    });
  }

  void _onSearchChanged() {
    final String query = _shell.queryFor(SearchHints.vehicles);
    if (query == _lastQuery) {
      return;
    }
    _lastQuery = query;
    _vehicles.load(buscar: query);
  }

  @override
  void dispose() {
    _shell.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _goToNew() {
    Navigator.pushNamed(context, Routes.vehicleNew);
  }

  void _goToDetail(Vehicle vehicle) {
    Navigator.pushNamed(
      context,
      Routes.vehicleDetail,
      arguments: VehicleDetailArgs(vehicleId: vehicle.id),
    );
  }

  void _goToEdit(Vehicle vehicle) {
    Navigator.pushNamed(
      context,
      Routes.vehicleEdit,
      arguments: VehicleFormArgs(vehicle: vehicle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final VehiclesProvider vehicles = context.watch<VehiclesProvider>();
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              FilledButton.icon(
                onPressed: _goToNew,
                icon: const Icon(
                  LucideIcons.plus,
                  size: AppMetrics.iconSizeSmall,
                ),
                label: const Text('Registrar vehículo'),
              ),
              const Spacer(),
              Text(_counterText(vehicles), style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _buildBody(vehicles)),
        ],
      ),
    );
  }

  String _counterText(VehiclesProvider vehicles) {
    if (vehicles.status != LoadStatus.ready) {
      return '';
    }
    final int total = vehicles.items.length;
    return total == 1 ? '1 vehículo' : '$total vehículos';
  }

  Widget _buildBody(VehiclesProvider vehicles) {
    switch (vehicles.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando vehículos…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: vehicles.error ?? AppMessages.unexpectedError,
          onRetry: _vehicles.reload,
        );
      case LoadStatus.ready:
        if (vehicles.items.isEmpty) {
          return EmptyView(
            mensaje: _lastQuery.isEmpty
                ? 'Todavía no hay vehículos registrados. Registra el primero '
                      'para empezar.'
                : 'No se encontraron vehículos que coincidan con '
                      '"$_lastQuery".',
            actionLabel: 'Registrar vehículo',
            onAction: _goToNew,
          );
        }
        return _buildTable(vehicles.items);
    }
  }

  Widget _buildTable(List<Vehicle> items) {
    final MotorixColors colors = context.motorixColors;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const <DataColumn>[
            DataColumn(label: Text('Vehículo')),
            DataColumn(label: Text('Placas')),
            DataColumn(label: Text('Año')),
            DataColumn(label: Text('Kilometraje')),
            DataColumn(label: Text('Propietario')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: <DataRow>[
            for (final Vehicle vehicle in items) _buildRow(vehicle, colors),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(Vehicle vehicle, MotorixColors colors) {
    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.hovered) ? colors.primarySoft : null,
      ),
      cells: <DataCell>[
        DataCell(
          Text(vehicle.descripcion),
          onTap: () => _goToDetail(vehicle),
        ),
        DataCell(Text(vehicle.placas)),
        DataCell(Text('${vehicle.anio}')),
        DataCell(Text(Formatters.mileage(vehicle.kilometrajeActual))),
        DataCell(Text(vehicle.dueno)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Ver detalle',
                onPressed: () => _goToDetail(vehicle),
                icon: const Icon(
                  LucideIcons.eye,
                  size: AppMetrics.iconSizeSmall,
                ),
              ),
              IconButton(
                tooltip: 'Editar',
                onPressed: () => _goToEdit(vehicle),
                icon: const Icon(
                  LucideIcons.pencil,
                  size: AppMetrics.iconSizeSmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
