import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/part.dart';
import '../providers/auth_provider.dart';
import '../providers/load_status.dart';
import '../providers/parts_provider.dart';
import '../providers/shell_provider.dart';
import '../services/api_client.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/status_chip.dart';
import 'part_detail_screen.dart';
import 'part_form_screen.dart';

/// Catálogo de refacciones del inventario (US5/HU5): búsqueda por nombre o
/// código (FR-018), stock actual/mínimo y precios (SC-005), y acciones de
/// escritura solo para ADMIN (FR-022). Término canónico: «refacción».
class PartsScreen extends StatefulWidget {
  const PartsScreen({super.key});

  @override
  State<PartsScreen> createState() => _PartsScreenState();
}

class _PartsScreenState extends State<PartsScreen> {
  late final ShellProvider _shell;
  late final PartsProvider _parts;

  /// El catálogo lo escribe solo ADMIN (FR-022); recepción y mecánico
  /// consultan. Ocultar no es seguridad: el backend valida cada operación.
  late final bool _puedeEscribir;

  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _shell = context.read<ShellProvider>();
    _parts = context.read<PartsProvider>();
    final String rol = context.read<AuthProvider>().user?.rol ?? '';
    _puedeEscribir = rol == Rol.admin;
    _lastQuery = _shell.queryFor(SearchHints.parts);
    _shell.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_lastQuery.isNotEmpty) {
        _parts.setBuscar(_lastQuery);
      } else if (_parts.status == LoadStatus.idle) {
        _parts.load();
      }
    });
  }

  void _onSearchChanged() {
    final String query = _shell.queryFor(SearchHints.parts);
    if (query == _lastQuery) {
      return;
    }
    _lastQuery = query;
    _parts.setBuscar(query);
  }

  @override
  void dispose() {
    _shell.removeListener(_onSearchChanged);
    super.dispose();
  }

  Future<void> _goToNew() async {
    final bool? creado = await Navigator.pushNamed<bool>(
      context,
      Routes.partNew,
    );
    if (creado == true && mounted) {
      _parts.reload();
    }
  }

  Future<void> _goToEdit(Part part) async {
    final bool? editado = await Navigator.pushNamed<bool>(
      context,
      Routes.partEdit,
      arguments: PartFormArgs(refaccion: part),
    );
    if (editado == true && mounted) {
      _parts.reload();
    }
  }

  /// Abre el detalle con los datos de la refacción y su historial de
  /// movimientos (US6, FR-030). Una refacción desactivada también se abre:
  /// su historial persiste (FR-019).
  Future<void> _goToDetail(Part part) async {
    await Navigator.pushNamed(
      context,
      Routes.partDetail,
      arguments: PartDetailArgs(refaccionId: part.id),
    );
  }

  /// Desactivación con confirmación obligatoria (Principio VIII): la baja es
  /// de catálogo, el historial de la refacción persiste (FR-019).
  Future<void> _deactivate(Part part) async {
    final bool confirmado = await showConfirmDialog(
      context,
      titulo: 'Desactivar refacción',
      mensaje: '«${part.nombre}» dejará de poder agregarse a las órdenes, '
          'pero su historial de uso y sus movimientos se conservan. '
          '¿Continuar?',
      confirmarLabel: 'Desactivar',
    );
    if (!confirmado || !mounted) {
      return;
    }
    try {
      await _parts.deactivate(part.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refacción desactivada.')),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppMessages.unexpectedError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final PartsProvider parts = context.watch<PartsProvider>();
    final MotorixColors colors = context.motorixColors;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: _buildHeader(parts)),
              const SizedBox(width: AppSpacing.md),
              // Filtro de alertas (US8, SC-008): el backend solo devuelve
              // las refacciones con stock_actual <= stock_minimo.
              ChoiceChip(
                key: const Key('filtro-stock-bajo'),
                avatar: Icon(
                  LucideIcons.triangleAlert,
                  size: AppMetrics.iconSizeSmall,
                  color:
                      parts.soloStockBajo ? colors.danger : colors.textSecondary,
                ),
                label: const Text('Solo stock bajo'),
                selected: parts.soloStockBajo,
                onSelected: (bool seleccionado) =>
                    _parts.setSoloStockBajo(seleccionado),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: parts.soloStockBajo
                          ? colors.danger
                          : colors.textPrimary,
                    ),
                selectedColor: colors.danger.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.panel),
                  side: BorderSide(
                    color:
                        parts.soloStockBajo ? colors.danger : colors.outline,
                  ),
                ),
                showCheckmark: false,
              ),
              if (_puedeEscribir) ...<Widget>[
                const SizedBox(width: AppSpacing.md),
                FilledButton.icon(
                  onPressed: _goToNew,
                  icon: const Icon(
                    LucideIcons.plus,
                    size: AppMetrics.iconSizeSmall,
                  ),
                  label: const Text('Nueva refacción'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _buildBody(parts)),
          if (parts.status == LoadStatus.ready && parts.total > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _buildPagination(parts),
          ],
        ],
      ),
    );
  }

  /// Contador del catálogo con el total del backend: con el filtro de
  /// alertas activo (US8) el total ya sale filtrado de la API.
  Widget _buildHeader(PartsProvider parts) {
    return Text(
      parts.soloStockBajo
          ? 'Inventario · ${parts.total} refacciones con stock bajo'
          : 'Inventario · ${parts.total} refacciones',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _buildBody(PartsProvider parts) {
    switch (parts.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando el inventario…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: parts.error ?? AppMessages.unexpectedError,
          onRetry: _parts.reload,
        );
      case LoadStatus.ready:
        if (parts.items.isEmpty) {
          return EmptyView(
            mensaje: parts.soloStockBajo
                ? 'No hay refacciones con stock bajo. Cuando una refacción '
                    'llegue a su stock mínimo aparecerá en esta lista de '
                    'alertas.'
                : parts.buscar.isEmpty
                    ? 'El inventario está vacío. Registra la primera refacción '
                        'con el botón «Nueva refacción» y podrá usarse en las '
                        'órdenes de servicio.'
                    : 'No hay refacciones que coincidan con la búsqueda.',
          );
        }
        return ListView.separated(
          itemCount: parts.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (BuildContext context, int index) =>
              _buildItemCard(parts.items[index]),
        );
    }
  }

  Widget _buildItemCard(Part part) {
    final MotorixColors colors = context.motorixColors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppPanel(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: part.activa ? colors.outline : colors.textSecondary,
              width: 4,
            ),
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
                        child: Text(part.nombre, style: textTheme.titleMedium),
                      ),
                      // Semáforo de alerta (US8, SC-008): visible de un
                      // vistazo al abrir el inventario.
                      if (part.stockBajo) ...<Widget>[
                        const StockBajoChip(),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        part.codigo,
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${part.categoria}'
                    '${part.marca != null ? ' · ${part.marca}' : ''}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      _buildMeta(
                        LucideIcons.package,
                        'Stock: ${Formatters.number(part.stockActual)} '
                            '· mín. ${Formatters.number(part.stockMinimo)}',
                        colors,
                        textTheme,
                        // Stock por debajo del mínimo en `danger` (DS).
                        color: part.stockBajo ? colors.danger : null,
                      ),
                      if (part.precioCompra != null)
                        _buildMeta(
                          LucideIcons.arrowDownToLine,
                          'Compra: ${Formatters.money(part.precioCompra!)}',
                          colors,
                          textTheme,
                        ),
                      if (part.precioVenta != null)
                        _buildMeta(
                          LucideIcons.arrowUpFromLine,
                          'Venta: ${Formatters.money(part.precioVenta!)}',
                          colors,
                          textTheme,
                        ),
                      if (!part.activa)
                        _buildMeta(
                          LucideIcons.circleOff,
                          'Desactivada',
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
                tooltip: 'Ver detalle',
                onPressed: () => _goToDetail(part),
                icon: const Icon(
                  LucideIcons.eye,
                  size: AppMetrics.iconSizeSmall,
                ),
              ),
              if (part.activa) ...<Widget>[
                IconButton(
                  tooltip: 'Editar refacción',
                  onPressed: () => _goToEdit(part),
                  icon: const Icon(
                    LucideIcons.pencil,
                    size: AppMetrics.iconSizeSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Desactivar refacción',
                  onPressed: () => _deactivate(part),
                  icon: const Icon(
                    LucideIcons.circleOff,
                    size: AppMetrics.iconSizeSmall,
                  ),
                ),
              ],
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
    TextTheme textTheme, {
    Color? color,
  }) {
    final Color tono = color ?? colors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: AppMetrics.iconSizeSmall, color: tono),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            texto,
            style: textTheme.bodySmall?.copyWith(color: tono),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination(PartsProvider parts) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Text(
          'Mostrando ${parts.items.length} de ${parts.total}',
          style: textTheme.bodySmall,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Página anterior',
          onPressed: parts.pagina > 1
              ? () => _parts.goToPage(parts.pagina - 1)
              : null,
          icon: const Icon(
            LucideIcons.chevronLeft,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Página ${parts.pagina} de ${parts.paginas}',
            style: textTheme.bodySmall,
          ),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: parts.pagina < parts.paginas
              ? () => _parts.goToPage(parts.pagina + 1)
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
