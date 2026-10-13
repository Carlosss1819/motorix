import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/part.dart';
import '../models/part_movement.dart';
import '../providers/load_status.dart';
import '../providers/part_detail_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';

/// Argumento de la ruta del detalle de refacción.
class PartDetailArgs {
  const PartDetailArgs({required this.refaccionId});

  final int refaccionId;
}

/// Detalle de una refacción (US6/HU6): sus datos de catálogo y el historial
/// de movimientos que explica cada cambio de stock, con orden, stock
/// resultante y fecha (FR-018, FR-030, SC-007).
class PartDetailScreen extends StatefulWidget {
  const PartDetailScreen({super.key, required this.args});

  final PartDetailArgs args;

  @override
  State<PartDetailScreen> createState() => _PartDetailScreenState();
}

class _PartDetailScreenState extends State<PartDetailScreen> {
  late final PartDetailProvider _detail;

  @override
  void initState() {
    super.initState();
    _detail = context.read<PartDetailProvider>();
    _detail.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _detail.load(widget.args.refaccionId);
      }
    });
  }

  @override
  void dispose() {
    _detail.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PartDetailProvider detail = context.watch<PartDetailProvider>();

    switch (detail.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando refacción…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: detail.error ?? AppMessages.unexpectedError,
          onRetry: _detail.reload,
        );
      case LoadStatus.ready:
        final Part? part = detail.part;
        if (part == null) {
          return const ErrorView(mensaje: 'No se encontró la refacción.');
        }
        return _buildContent(detail, part);
    }
  }

  Widget _buildContent(PartDetailProvider detail, Part part) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

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
                    part.nombre,
                    style: textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  part.codigo,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildDataPanel(part),
            const SizedBox(height: AppSpacing.lg),
            _buildMovementsPanel(detail),
          ],
        ),
      ),
    );
  }

  Widget _buildDataPanel(Part part) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Datos de la refacción', style: textTheme.titleMedium),
              ),
              StatusChip(activo: part.activa),
              if (part.stockBajo) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                const _StockLowChip(),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DetailRow(label: 'Categoría', value: part.categoria),
          DetailRow(
            label: 'Marca',
            value: part.marca ?? 'Sin marca registrada',
          ),
          DetailRow(
            label: 'Stock actual',
            value: '${Formatters.number(part.stockActual)} unidades',
          ),
          DetailRow(
            label: 'Stock mínimo',
            value: '${Formatters.number(part.stockMinimo)} unidades',
          ),
          DetailRow(
            label: 'Precio de compra',
            value: part.precioCompra != null
                ? Formatters.money(part.precioCompra!)
                : 'Sin registro',
          ),
          DetailRow(
            label: 'Precio de venta',
            value: part.precioVenta != null
                ? Formatters.money(part.precioVenta!)
                : 'Sin registro',
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsPanel(PartDetailProvider detail) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Movimientos de inventario',
                  style: textTheme.titleMedium,
                ),
              ),
              if (detail.total > 0)
                Text(_counterText(detail.total), style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (detail.items.isEmpty)
            Text(
              'Esta refacción todavía no tiene movimientos. Cada entrada, '
              'salida y ajuste quedará aquí con su stock resultante.',
              style: textTheme.bodyMedium?.copyWith(
                color: context.motorixColors.textSecondary,
              ),
            )
          else
            _buildMovementsTable(detail),
        ],
      ),
    );
  }

  String _counterText(int total) {
    return total == 1 ? '1 movimiento' : '$total movimientos';
  }

  Widget _buildMovementsTable(PartDetailProvider detail) {
    final List<PartMovement> items = detail.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('Tipo')),
              DataColumn(label: Text('Cantidad')),
              DataColumn(label: Text('Motivo')),
              DataColumn(label: Text('Orden')),
              DataColumn(label: Text('Stock resultante')),
              DataColumn(label: Text('Fecha')),
            ],
            rows: <DataRow>[
              for (final PartMovement movement in items) _buildRow(movement),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildPagination(detail, items.length),
      ],
    );
  }

  DataRow _buildRow(PartMovement movement) {
    return DataRow(
      cells: <DataCell>[
        DataCell(_MovementTypeChip(tipo: movement.tipo)),
        DataCell(Text(_quantityText(movement))),
        DataCell(Text(movement.motivo ?? 'Sin motivo')),
        DataCell(
          Text(movement.ordenId != null ? '#${movement.ordenId}' : 'Sin orden'),
        ),
        DataCell(Text(Formatters.number(movement.stockAfter))),
        DataCell(Text(Formatters.dateTime(movement.fecha))),
      ],
    );
  }

  /// ENTRADA y AJUSTE aumentan el stock; SALIDA lo descuenta (contrato
  /// contracts/parts.md). El signo deja ver el efecto de cada fila.
  String _quantityText(PartMovement movement) {
    final String signo = movement.tipo == 'SALIDA' ? '-' : '+';
    return '$signo${Formatters.number(movement.cantidad)}';
  }

  Widget _buildPagination(PartDetailProvider detail, int mostrados) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int total = detail.total;
    final int pagina = detail.pagina;
    final int paginas = detail.paginas;

    if (total <= 0) {
      return const SizedBox.shrink();
    }

    return Row(
      children: <Widget>[
        Text('Mostrando $mostrados de $total', style: textTheme.bodySmall),
        const Spacer(),
        IconButton(
          tooltip: 'Página anterior',
          onPressed: pagina > 1 ? () => detail.goToPage(pagina - 1) : null,
          icon: const Icon(
            LucideIcons.chevronLeft,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('Página $pagina de $paginas', style: textTheme.bodySmall),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: pagina < paginas ? () => detail.goToPage(pagina + 1) : null,
          icon: const Icon(
            LucideIcons.chevronRight,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
      ],
    );
  }
}

/// Chip del tipo de movimiento: entrada en verde, salida en rojo y ajuste en
/// ámbar, siguiendo el semáforo de docs/design-system.md.
class _MovementTypeChip extends StatelessWidget {
  const _MovementTypeChip({required this.tipo});

  final String tipo;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final Color color = switch (tipo) {
      'ENTRADA' => colors.success,
      'SALIDA' => colors.danger,
      _ => colors.warning,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        switch (tipo) {
          'ENTRADA' => 'Entrada',
          'SALIDA' => 'Salida',
          'AJUSTE' => 'Ajuste',
          _ => tipo,
        },
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color),
      ),
    );
  }
}

/// Aviso de existencias por debajo del mínimo (FR-020): el mínimo en 0 nunca
/// se marca, porque el propio backend no lo reporta como alerta (FR-021).
class _StockLowChip extends StatelessWidget {
  const _StockLowChip();

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Stock bajo',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: colors.warning),
      ),
    );
  }
}
