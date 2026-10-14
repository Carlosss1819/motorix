import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/service_order.dart';
import '../providers/auth_provider.dart';
import '../providers/load_status.dart';
import '../providers/service_orders_provider.dart';
import '../providers/shell_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/app_table.dart';
import '../widgets/common_views.dart';
import '../widgets/status_chip.dart';
import 'service_order_detail_screen.dart';

/// Lista de órdenes de servicio (US1/HU1): tabla densa con filtro por estado,
/// búsqueda por placas o nombre del cliente (FR-003) y paginación.
class ServiceOrdersScreen extends StatefulWidget {
  const ServiceOrdersScreen({super.key});

  @override
  State<ServiceOrdersScreen> createState() => _ServiceOrdersScreenState();
}

class _ServiceOrdersScreenState extends State<ServiceOrdersScreen> {
  late final ShellProvider _shell;
  late final ServiceOrdersProvider _orders;

  /// Con rol MECHANIC la pantalla es "Mis órdenes" (US3/FR-010): el backend
  /// acota el listado a las órdenes propias y aquí se ocultan la alta y el
  /// filtro global de estado.
  late final bool _esMecanico;

  String _lastQuery = '';
  String _estado = kTodosLosEstados;

  @override
  void initState() {
    super.initState();
    _shell = context.read<ShellProvider>();
    _orders = context.read<ServiceOrdersProvider>();
    _esMecanico = context.read<AuthProvider>().user?.rol == Rol.mechanic;
    _lastQuery = _shell.queryFor(SearchHints.orders);
    _estado = _orders.estado;
    _shell.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_lastQuery.isNotEmpty) {
        _orders.setBuscar(_lastQuery);
      } else if (_orders.status == LoadStatus.idle) {
        _orders.load();
      }
    });
  }

  void _onSearchChanged() {
    final String query = _shell.queryFor(SearchHints.orders);
    if (query == _lastQuery) {
      return;
    }
    _lastQuery = query;
    _orders.setBuscar(query);
  }

  @override
  void dispose() {
    _shell.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _goToNew() async {
    // Sin el parámetro <bool> a propósito: `onGenerateRoute` devuelve una
    // ruta `Route<dynamic>` y el cast a `Route<bool>` revienta `pushNamed`
    // en tiempo de ejecución (la navegación moriría en silencio).
    final Object? creado = await Navigator.pushNamed(
      context,
      Routes.serviceOrderNew,
    );
    if (creado == true && mounted) {
      _orders.load();
    }
  }

  void _goToDetail(ServiceOrder order) {
    Navigator.pushNamed(
      context,
      Routes.serviceOrderDetail,
      arguments: ServiceOrderDetailArgs(orderId: order.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ServiceOrdersProvider orders = context.watch<ServiceOrdersProvider>();
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!_esMecanico) ...<Widget>[
                FilledButton.icon(
                  onPressed: _goToNew,
                  icon: const Icon(
                    LucideIcons.plus,
                    size: AppMetrics.iconSizeSmall,
                  ),
                  label: const Text('Registrar orden'),
                ),
                const SizedBox(width: AppSpacing.lg),
                _buildStatusFilter(orders),
                const SizedBox(width: AppSpacing.lg),
              ],
              const Spacer(),
              Text(_counterText(orders), style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _buildBody(orders)),
          if (orders.status == LoadStatus.ready && orders.total > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _buildPagination(orders),
          ],
        ],
      ),
    );
  }

  String _counterText(ServiceOrdersProvider orders) {
    if (orders.status != LoadStatus.ready) {
      return '';
    }
    final int total = orders.total;
    return total == 1 ? '1 orden' : '$total órdenes';
  }

  /// Selector de estado de orden (FR-014).
  Widget _buildStatusFilter(ServiceOrdersProvider orders) {
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
            value: kTodosLosEstados,
            child: Text('Todos los estados'),
          ),
          for (final String estado in orderStatusValues)
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
          _orders.setEstado(value);
        },
      ),
    );
  }

  Widget _buildBody(ServiceOrdersProvider orders) {
    switch (orders.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando órdenes…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: orders.error ?? AppMessages.unexpectedError,
          onRetry: _orders.reload,
        );
      case LoadStatus.ready:
        if (orders.items.isEmpty) {
          return EmptyView(
            mensaje: _emptyMessage(orders),
            // El mecánico no da de alta órdenes desde esta pantalla.
            actionLabel: _esMecanico ? null : 'Registrar orden',
            onAction: _esMecanico ? null : _goToNew,
          );
        }
        return _buildTable(orders.items);
    }
  }

  String _emptyMessage(ServiceOrdersProvider orders) {
    if (_lastQuery.isNotEmpty) {
      return 'No se encontraron órdenes que coincidan con "$_lastQuery".';
    }
    if (_esMecanico) {
      return 'No tienes órdenes asignadas por el momento.';
    }
    if (_estado != kTodosLosEstados) {
      return 'No hay órdenes en estado ${orderStatusLabel(_estado)}.';
    }
    return 'Todavía no hay órdenes de servicio. Registra la primera para '
        'empezar.';
  }

  Widget _buildTable(List<ServiceOrder> items) {
    final MotorixColors colors = context.motorixColors;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: FullWidthTable(
        columns: <DataColumn>[
          fluidColumn('Folio', weight: 1, minWidth: 110),
          fluidColumn('Cliente', weight: 1.4, minWidth: 130),
          fluidColumn('Vehículo', weight: 1.5, minWidth: 140),
          fluidColumn('Estado', weight: 1.2, minWidth: 120),
          fluidColumn('Motivo de visita', weight: 1.8, minWidth: 150),
          fluidColumn('Ingreso', weight: 1.2, minWidth: 130),
          fluidColumn('Kilometraje', weight: 1, minWidth: 130),
          fluidColumn('Mecánico', weight: 1.3, minWidth: 130),
          fluidColumn('Acciones', weight: 1, minWidth: 120),
        ],
        rows: <DataRow>[
          for (final ServiceOrder order in items) _buildRow(order, colors),
        ],
      ),
    );
  }

  DataRow _buildRow(ServiceOrder order, MotorixColors colors) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.hovered) ? colors.primarySoft : null,
      ),
      cells: <DataCell>[
        DataCell(
          Text('#${order.id}'),
          onTap: () => _goToDetail(order),
        ),
        DataCell(
          Text(order.cliente, overflow: TextOverflow.ellipsis),
          onTap: () => _goToDetail(order),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                order.vehiculo,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
              Text(
                order.placas,
                style: textTheme.labelSmall
                    ?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          onTap: () => _goToDetail(order),
        ),
        DataCell(OrderStatusChip(estado: order.estado)),
        DataCell(
          Text(order.motivoVisita, overflow: TextOverflow.ellipsis),
          onTap: () => _goToDetail(order),
        ),
        DataCell(Text(Formatters.date(order.fechaIngreso))),
        DataCell(Text(Formatters.mileage(order.kilometrajeEntrada))),
        DataCell(Text(order.mecanico ?? 'Sin asignar')),
        DataCell(
          IconButton(
            tooltip: 'Ver detalle',
            onPressed: () => _goToDetail(order),
            icon: const Icon(
              LucideIcons.eye,
              size: AppMetrics.iconSizeSmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination(ServiceOrdersProvider orders) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Text(
          'Mostrando ${orders.items.length} de ${orders.total}',
          style: textTheme.bodySmall,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Página anterior',
          onPressed:
              orders.pagina > 1 ? () => _orders.goToPage(orders.pagina - 1) : null,
          icon: const Icon(
            LucideIcons.chevronLeft,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Página ${orders.pagina} de ${orders.paginas}',
            style: textTheme.bodySmall,
          ),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: orders.pagina < orders.paginas
              ? () => _orders.goToPage(orders.pagina + 1)
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
