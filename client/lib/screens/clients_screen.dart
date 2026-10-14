import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/client.dart';
import '../providers/clients_provider.dart';
import '../providers/load_status.dart';
import '../providers/shell_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/app_table.dart';
import '../widgets/common_views.dart';
import 'client_detail_screen.dart';
import 'client_form_screen.dart';

/// Lista de clientes (US3): búsqueda por nombre, teléfono o correo.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late final ShellProvider _shell;
  late final ClientsProvider _clients;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _shell = context.read<ShellProvider>();
    _clients = context.read<ClientsProvider>();
    _lastQuery = _shell.queryFor(SearchHints.clients);
    _shell.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _clients.load(buscar: _lastQuery);
    });
  }

  void _onSearchChanged() {
    final String query = _shell.queryFor(SearchHints.clients);
    if (query == _lastQuery) {
      return;
    }
    _lastQuery = query;
    _clients.load(buscar: query);
  }

  @override
  void dispose() {
    _shell.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _goToNew() {
    Navigator.pushNamed(context, Routes.clientNew);
  }

  void _goToDetail(Client client) {
    Navigator.pushNamed(
      context,
      Routes.clientDetail,
      arguments: ClientDetailArgs(clientId: client.id),
    );
  }

  void _goToEdit(Client client) {
    Navigator.pushNamed(
      context,
      Routes.clientEdit,
      arguments: ClientFormArgs(client: client),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ClientsProvider clients = context.watch<ClientsProvider>();
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
                  LucideIcons.userPlus,
                  size: AppMetrics.iconSizeSmall,
                ),
                label: const Text('Registrar cliente'),
              ),
              const Spacer(),
              Text(_counterText(clients), style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _buildBody(clients)),
        ],
      ),
    );
  }

  String _counterText(ClientsProvider clients) {
    if (clients.status != LoadStatus.ready) {
      return '';
    }
    final int total = clients.items.length;
    return total == 1 ? '1 cliente' : '$total clientes';
  }

  Widget _buildBody(ClientsProvider clients) {
    switch (clients.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando clientes…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: clients.error ?? AppMessages.unexpectedError,
          onRetry: _clients.reload,
        );
      case LoadStatus.ready:
        if (clients.items.isEmpty) {
          return EmptyView(
            mensaje: _lastQuery.isEmpty
                ? 'Todavía no hay clientes registrados. Registra el primero '
                      'para empezar.'
                : 'No se encontraron clientes que coincidan con '
                      '"$_lastQuery".',
            actionLabel: 'Registrar cliente',
            onAction: _goToNew,
          );
        }
        return _buildTable(clients.items);
    }
  }

  Widget _buildTable(List<Client> items) {
    final MotorixColors colors = context.motorixColors;
    return AppPanel(
      padding: EdgeInsets.zero,
      child: FullWidthTable(
        columns: <DataColumn>[
          fluidColumn('Nombre', weight: 1.6, minWidth: 140),
          fluidColumn('Teléfono', weight: 1.2, minWidth: 120),
          fluidColumn('Correo', weight: 2, minWidth: 150),
          fluidColumn('Registro', weight: 1.2, minWidth: 130),
          fluidColumn('Estado', weight: 1, minWidth: 120),
          fluidColumn('Acciones', weight: 1, minWidth: 150),
        ],
        rows: <DataRow>[
          for (final Client client in items) _buildRow(client, colors),
        ],
      ),
    );
  }

  DataRow _buildRow(Client client, MotorixColors colors) {
    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) =>
            states.contains(WidgetState.hovered) ? colors.primarySoft : null,
      ),
      cells: <DataCell>[
        DataCell(
          Text(client.nombre),
          onTap: () => _goToDetail(client),
        ),
        DataCell(Text(client.telefono)),
        DataCell(Text(client.email ?? 'Sin correo')),
        DataCell(Text(Formatters.date(client.fechaRegistro))),
        DataCell(StatusChip(activo: client.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Ver detalle',
                onPressed: () => _goToDetail(client),
                icon: const Icon(
                  LucideIcons.eye,
                  size: AppMetrics.iconSizeSmall,
                ),
              ),
              IconButton(
                tooltip: 'Editar',
                onPressed: () => _goToEdit(client),
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
