import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/dashboard_summary.dart';
import '../models/service_order.dart';
import '../providers/dashboard_provider.dart';
import '../providers/load_status.dart';
import '../utils/app_theme.dart';
import '../utils/messages.dart';
import '../widgets/common_views.dart';
import '../widgets/status_chip.dart';

/// Panel de control del administrador (HU5, FR-010/FR-011, Sprint 4): en US5
/// muestra el resumen de órdenes con una sola petición al abrir y la acción
/// «Actualizar» (D4); los bloques operativos se agregan en US6.
///
/// Solo ADMIN abre esta pantalla: la navegación la oculta para otros roles y
/// el backend responde `403 PANEL_SOLO_ADMIN` (doble filtro, HU5-2, RN-15).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardProvider _panel;

  @override
  void initState() {
    super.initState();
    _panel = context.read<DashboardProvider>();
    // Carga en post-frame para no notificar a los oyentes durante la
    // construcción de la ruta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _panel.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final DashboardProvider panel = context.watch<DashboardProvider>();
    final DashboardSummary? resumen = panel.resumen;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Panel de control', style: textTheme.titleLarge),
                ),
                FilledButton.tonalIcon(
                  key: const Key('boton-actualizar'),
                  onPressed: panel.status == LoadStatus.loading
                      ? null
                      : () => panel.load(),
                  icon: const Icon(
                    LucideIcons.refreshCw,
                    size: AppMetrics.iconSizeSmall,
                  ),
                  label: const Text('Actualizar'),
                ),
              ],
            ),
            if (resumen != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Resumen del taller al ${resumen.fecha}',
                key: const Key('fecha-referencia'),
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _buildContenido(panel),
          ],
        ),
      ),
    );
  }

  /// Estados de la carga del panel: carga, error con reintento y contenido.
  Widget _buildContenido(DashboardProvider panel) {
    if (panel.status == LoadStatus.loading ||
        panel.status == LoadStatus.idle) {
      return const LoadingView(mensaje: 'Cargando panel…');
    }
    if (panel.status == LoadStatus.error) {
      return ErrorView(
        mensaje: panel.error ?? AppMessages.unexpectedError,
        onRetry: () => panel.load(),
      );
    }
    final DashboardSummary? resumen = panel.resumen;
    if (resumen == null) {
      return ErrorView(
        mensaje: AppMessages.unexpectedError,
        onRetry: () => panel.load(),
      );
    }
    return _buildResumen(resumen);
  }

  /// Bloque de resumen de órdenes (US5): totales y desglose por estado con
  /// datos reales, o estado vacío amigable cuando no hay órdenes (HU6-4).
  Widget _buildResumen(DashboardSummary resumen) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final DashboardOrdersBlock ordenes = resumen.ordenes;

    if (ordenes.vacio) {
      return EmptyView(
        key: const Key('panel-vacio'),
        mensaje:
            'Todavía no hay órdenes registradas: el resumen aparecerá cuando '
            'se abra la primera orden.',
      );
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Órdenes', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          DetailRow(
            key: const Key('valor-total-ordenes'),
            label: 'Total',
            value: '${ordenes.total}',
          ),
          DetailRow(
            key: const Key('valor-abiertas-ordenes'),
            label: 'Abiertas',
            value: '${ordenes.abiertas}',
          ),
          DetailRow(
            key: const Key('valor-entregadas-ordenes'),
            label: 'Entregadas',
            value: '${ordenes.entregadas}',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Por estado',
            style: textTheme.bodySmall?.copyWith(
              color: context.motorixColors.textSecondary,
            ),
          ),
          for (final String estado in orderStatusValues)
            DetailRow(
              key: Key('valor-estado-$estado'),
              label: orderStatusLabel(estado),
              value: '${ordenes.porEstado[estado] ?? 0}',
            ),
        ],
      ),
    );
  }
}
