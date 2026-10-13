import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/vehicle_history.dart';
import '../providers/load_status.dart';
import '../providers/vehicle_history_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import '../widgets/status_chip.dart';

/// Argumento de la ruta del historial del vehículo.
class VehicleHistoryArgs {
  const VehicleHistoryArgs({required this.vehicleId, this.vehicleLabel});

  final int vehicleId;

  /// Etiqueta del vehículo para el encabezado (opcional).
  final String? vehicleLabel;
}

/// Historial de un vehículo (US1/HU1): entradas derivadas de las órdenes
/// terminadas o entregadas con fecha, kilometraje, estado y el detalle del
/// servicio (FR-001 a FR-003).
class VehicleHistoryScreen extends StatefulWidget {
  const VehicleHistoryScreen({super.key, required this.args});

  final VehicleHistoryArgs args;

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  late final VehicleHistoryProvider _history;

  @override
  void initState() {
    super.initState();
    _history = context.read<VehicleHistoryProvider>();
    _history.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _history.load(widget.args.vehicleId);
      }
    });
  }

  @override
  void dispose() {
    _history.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VehicleHistoryProvider history =
        context.watch<VehicleHistoryProvider>();
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Historial del vehículo', style: textTheme.titleLarge),
                    if (widget.args.vehicleLabel != null)
                      Text(
                        widget.args.vehicleLabel!,
                        style: textTheme.bodySmall?.copyWith(
                          color: context.motorixColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (history.status == LoadStatus.ready)
                Text(_counterText(history), style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: _buildBody(history)),
          if (history.status == LoadStatus.ready && history.total > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _buildPagination(history),
          ],
        ],
      ),
    );
  }

  String _counterText(VehicleHistoryProvider history) {
    final int total = history.total;
    return total == 1 ? '1 servicio' : '$total servicios';
  }

  Widget _buildBody(VehicleHistoryProvider history) {
    switch (history.status) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const LoadingView(mensaje: 'Cargando historial…');
      case LoadStatus.error:
        return ErrorView(
          mensaje: history.error ?? AppMessages.unexpectedError,
          onRetry: _history.reload,
        );
      case LoadStatus.ready:
        if (history.items.isEmpty) {
          return const EmptyView(
            mensaje: 'Este vehículo todavía no tiene servicios terminados. '
                'El historial se completa cuando una orden pasa a terminada '
                'o entregada.',
          );
        }
        return ListView.separated(
          itemCount: history.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
          itemBuilder: (BuildContext context, int index) =>
              _buildEntryCard(history.items[index]),
        );
    }
  }

  Widget _buildEntryCard(HistoryEntry entry) {
    final MotorixColors colors = context.motorixColors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                LucideIcons.history,
                size: AppMetrics.iconSizeSmall,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                Formatters.date(entry.fechaServicio),
                style: textTheme.titleMedium,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                Formatters.mileage(entry.kilometraje),
                style: textTheme.bodySmall
                    ?.copyWith(color: colors.textSecondary),
              ),
              const Spacer(),
              OrderStatusChip(estado: entry.estadoOrden),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (entry.observaciones != null && entry.observaciones!.isNotEmpty)
            _buildSection('Motivo de visita', <Widget>[
              Text(entry.observaciones!, style: textTheme.bodyMedium),
            ]),
          if (entry.diagnostico != null && entry.diagnostico!.isNotEmpty)
            _buildSection('Diagnóstico', <Widget>[
              Text(entry.diagnostico!, style: textTheme.bodyMedium),
            ]),
          if (entry.servicios.isNotEmpty)
            _buildSection('Servicios realizados', <Widget>[
              for (final String servicio in entry.servicios)
                _buildBullet(servicio, colors),
            ]),
          if (entry.refacciones.isNotEmpty)
            _buildSection('Refacciones', <Widget>[
              for (final HistoryPart refaccion in entry.refacciones)
                _buildBullet(
                  refaccion.codigo != null
                      ? '${refaccion.codigo} · ${refaccion.nombre} '
                          '(x${refaccion.cantidad})'
                      : '${refaccion.nombre} (x${refaccion.cantidad})',
                  colors,
                ),
            ]),
          if (entry.recomendaciones != null &&
              entry.recomendaciones!.isNotEmpty)
            _buildSection('Recomendaciones', <Widget>[
              Text(entry.recomendaciones!, style: textTheme.bodyMedium),
            ]),
        ],
      ),
    );
  }

  Widget _buildSection(String titulo, List<Widget> children) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            titulo,
            style: textTheme.labelMedium?.copyWith(
              color: context.motorixColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBullet(String texto, MotorixColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              LucideIcons.circle,
              size: 6,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildPagination(VehicleHistoryProvider history) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Text(
          'Mostrando ${history.items.length} de ${history.total}',
          style: textTheme.bodySmall,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Página anterior',
          onPressed: history.pagina > 1
              ? () => _history.goToPage(history.pagina - 1)
              : null,
          icon: const Icon(
            LucideIcons.chevronLeft,
            size: AppMetrics.iconSizeSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'Página ${history.pagina} de ${history.paginas}',
            style: textTheme.bodySmall,
          ),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: history.pagina < history.paginas
              ? () => _history.goToPage(history.pagina + 1)
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
