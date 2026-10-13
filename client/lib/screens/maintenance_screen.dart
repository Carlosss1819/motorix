import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/maintenance.dart';
import '../providers/auth_provider.dart';
import '../providers/load_status.dart';
import '../providers/maintenance_provider.dart';
import '../providers/shell_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import '../widgets/status_chip.dart';
import 'maintenance_form_screen.dart';

/// Lista de mantenimientos preventivos (US4/HU4): filtros por estado calculado
/// con chips, vencidos destacados en rojo, búsqueda del header por tipo o
/// placas y paginación R-10 (FR-012, FR-013, R-12 §16).
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late final ShellProvider _shell;
  late final MaintenanceProvider _maintenance;

  /// Con ADMIN/MECHANIC se ofrecen «Programar» y «Editar» (FR-008); recepción
  /// solo consulta (HU4, V3): ocultar no es seguridad, el backend valida.
  late final bool _puedeEscribir;

  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _shell = context.read<ShellProvider>();
    _maintenance = context.read<MaintenanceProvider>();
    final String rol = context.read<AuthProvider>().user?.rol ?? '';
    _puedeEscribir = rol == Rol.admin || rol == Rol.mechanic;
    _lastQuery = _shell.queryFor(SearchHints.maintenance);
    _shell.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_lastQuery.isNotEmpty) {
        _maintenance.setBuscar(_lastQuery);
      } else if (_maintenance.status == LoadStatus.idle) {
        _maintenance.load();
      }
    });
  }

  void _onSearchChanged() {
    final String query = _shell.queryFor(SearchHints.maintenance);
    if (query == _lastQuery) {
      return;
    }
    _lastQuery = query;
    _maintenance.setBuscar(query);
  }

  @override
  void dispose() {
    _shell.removeListener(_onSearchChanged);
    super.dispose();
  }

  Future<void> _goToNew() async {
    final bool? creado = await Navigator.pushNamed<bool>(
      context,
      Routes.maintenanceNew,
    );
    if (creado == true && mounted) {
      _maintenance.reload();
    }
  }

  Future<void> _goToEdit(Maintenance item) async {
    final bool? editado = await Navigator.pushNamed<bool>(
      context,
      Routes.maintenanceEdit,
      arguments: MaintenanceFormArgs(mantenimiento: item),
    );
    if (editado == true && mounted) {
      _maintenance.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaintenanceProvider maintenance =
        context.watch<MaintenanceProvider>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: _buildStatusFilters(maintenance)),
              if (_puedeEscribir)
                FilledButton.icon(
                  onPressed: _goToNew,
                  icon: const Icon(
                    LucideIcons.plus,
                    size: AppMetrics.iconSizeSmall,
                  ),
                  label: const Text('Programar'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _buildBody(maintenance)),
          if (maintenance.status == LoadStatus.ready &&
              maintenance.total > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _buildPagination(maintenance),
          ],
        ],
      ),
    );
  }

  /// Chips de filtro por estado calculado (FR-012): Todos, Normal, Próximo y
  /// Vencido; el filtro se aplica en el backend sobre el estado derivado.
  Widget _buildStatusFilters(MaintenanceProvider maintenance) {
    return Wrap(
      spacing: AppSpacing.sm,
      children: <Widget>[
        for (final MapEntry<String, String> filtro in const <
            MapEntry<String, String>>[
          MapEntry<String, String>(kTodosLosEstadosMantenimiento, 'Todos'),
          MapEntry<String, String>('NORMAL', 'Normal'),
          MapEntry<String, String>('PROXIMO', 'Próximo'),
          MapEntry<String, String>('VENCIDO', 'Vencido'),
        ])
          ChoiceChip(
            label: Text(filtro.value),
            selected: maintenance.estado == filtro.key,
            onSelected: _maintenance.isLoading
                ? null
                : (_) => _maintenance.setEstado(filtro.key),
          ),
      ],
    );
  }

  Widget _buildBody(MaintenanceProvider maintenance) {
    switch (maintenance.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando mantenimientos…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: maintenance.error ?? AppMessages.unexpectedError,
          onRetry: _maintenance.reload,
        );
      case LoadStatus.ready:
        if (maintenance.items.isEmpty) {
          return EmptyView(
            mensaje: maintenance.estado == kTodosLosEstadosMantenimiento &&
                    maintenance.buscar.isEmpty
                ? 'No hay mantenimientos pendientes. Programa el próximo '
                    'servicio preventivo de un vehículo y aparecerá aquí con '
                    'su estado calculado.'
                : 'No hay mantenimientos con este filtro.',
          );
        }
        return ListView.separated(
          itemCount: maintenance.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (BuildContext context, int index) =>
              _buildItemCard(maintenance.items[index]),
        );
    }
  }

  Widget _buildItemCard(Maintenance item) {
    final MotorixColors colors = context.motorixColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    // Los vencidos se destacan con un borde rojo (HU4: la llamada de
    // seguimiento empieza por aquí).
    final bool vencido = item.estado == 'VENCIDO';
    final Color borde = vencido
        ? colors.danger
        : item.estado == 'PROXIMO'
            ? colors.warning
            : colors.outline;

    return AppPanel(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: borde, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.tipoServicio,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      MaintenanceStatusChip(estado: item.estado),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${item.vehiculo} · ${item.placas}'
                    '${item.cliente != null ? ' · ${item.cliente}' : ''}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      _buildMeta(
                        LucideIcons.history,
                        item.fechaUltimoServicio != null
                            ? 'Último: ${Formatters.date(item.fechaUltimoServicio!)}'
                                '${item.kilometrajeUltimoServicio != null ? ' · ${Formatters.mileage(item.kilometrajeUltimoServicio!)}' : ''}'
                            : 'Sin servicios registrados',
                        colors,
                        textTheme,
                      ),
                      _buildMeta(
                        LucideIcons.target,
                        item.fechaObjetivo != null
                            ? 'Próximo: ${Formatters.date(item.fechaObjetivo!)}'
                                '${item.kilometrajeObjetivo != null ? ' o ${Formatters.mileage(item.kilometrajeObjetivo!)}' : ''}'
                            : 'Próximo: ${Formatters.mileage(item.kilometrajeObjetivo ?? 0)}',
                        colors,
                        textTheme,
                      ),
                      if (item.notas != null && item.notas!.isNotEmpty)
                        _buildMeta(
                          LucideIcons.notepadText,
                          item.notas!,
                          colors,
                          textTheme,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_puedeEscribir) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              IconButton(
                tooltip: 'Editar mantenimiento',
                onPressed: () => _goToEdit(item),
                icon: const Icon(
                  LucideIcons.pencil,
                  size: AppMetrics.iconSizeSmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMeta(
    IconData icon,
    String texto,
    MotorixColors colors,
    TextTheme textTheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: AppMetrics.iconSizeSmall, color: colors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            texto,
            style:
                textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination(MaintenanceProvider maintenance) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Text(
          'Mostrando ${maintenance.items.length} de ${maintenance.total}',
          style: textTheme.bodySmall,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Página anterior',
          onPressed: maintenance.pagina > 1
              ? () => _maintenance.goToPage(maintenance.pagina - 1)
              : null,
          icon: const Icon(
            LucideIcons.chevronLeft,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Página ${maintenance.pagina} de ${maintenance.paginas}',
            style: textTheme.bodySmall,
          ),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: maintenance.pagina < maintenance.paginas
              ? () => _maintenance.goToPage(maintenance.pagina + 1)
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
