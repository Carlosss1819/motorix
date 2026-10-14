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

/// Panel de control del administrador (HU5/HU6, FR-010/FR-011, Sprint 4): el
/// resumen de órdenes (US5) y los bloques operativos de citas,
/// mantenimientos y alertas de inventario (US6) con una sola petición al abrir
/// y la acción «Actualizar» (D4, sin tiempo real).
///
/// Carga y error son estados globales de la pantalla (una sola petición);
/// cada bloque ofrece su estado vacío amigable cuando no tiene datos
/// (HU6-4).
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

  /// Los cuatro bloques del contrato, cada uno con su estado vacío (HU6-4).
  Widget _buildResumen(DashboardSummary resumen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _bloqueOrdenes(resumen.ordenes),
        const SizedBox(height: AppSpacing.lg),
        _bloqueCitas(resumen.citas),
        const SizedBox(height: AppSpacing.lg),
        _bloqueMantenimientos(resumen.mantenimientos),
        const SizedBox(height: AppSpacing.lg),
        _bloqueAlertas(resumen.alertasInventario),
      ],
    );
  }

  /// Bloque de resumen de órdenes (US5): totales y desglose por estado con
  /// datos reales, o estado vacío amigable cuando no hay órdenes.
  Widget _bloqueOrdenes(DashboardOrdersBlock ordenes) {
    final TextTheme textTheme = Theme.of(context).textTheme;

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

  /// Bloque de citas (US6): total de hoy y las próximas con su estado
  /// (FR-011). Vacío solo cuando no hay ninguna.
  Widget _bloqueCitas(DashboardAppointmentsBlock citas) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    if (citas.hoy == 0 && citas.proximas.isEmpty) {
      return EmptyView(
        key: const Key('citas-vacio'),
        mensaje: 'No hay citas para hoy ni próximas citas registradas.',
      );
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Citas', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          DetailRow(
            key: const Key('valor-citas-hoy'),
            label: 'Hoy',
            value: '${citas.hoy}',
          ),
          if (citas.proximas.isNotEmpty) ...<Widget>[
            Text(
              'Próximas',
              style: textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            for (final DashboardAppointmentLine cita in citas.proximas)
              Padding(
                key: Key('cita-${cita.id}'),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${cita.fecha} ${cita.hora} · ${cita.cliente}',
                        style: textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (cita.estado.isNotEmpty)
                      AppointmentStatusChip(estado: cita.estado),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Bloque de mantenimientos (US6): vencidos y próximos con el objetivo que
  /// disparó la alerta, reutilizando el estado calculado por el backend
  /// (FR-011).
  Widget _bloqueMantenimientos(DashboardMaintenancesBlock mantenimientos) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    if (mantenimientos.proximos.isEmpty &&
        mantenimientos.vencidos.isEmpty) {
      return EmptyView(
        key: const Key('mantenimientos-vacio'),
        mensaje: 'No hay mantenimientos próximos ni vencidos.',
      );
    }

    Widget seccion(
      String titulo,
      List<DashboardMaintenanceLine> registros,
      String tipoLlave,
    ) {
      if (registros.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            titulo,
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          for (final DashboardMaintenanceLine registro in registros)
            Padding(
              key: Key('$tipoLlave-${registro.id}'),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          registro.tipo,
                          style: textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      MaintenanceStatusChip(estado: registro.estado),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${registro.vehiculo} · Objetivo: ${registro.objetivo}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Mantenimientos', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          seccion('Vencidos', mantenimientos.vencidos, 'mantenimiento-vencido'),
          seccion('Próximos', mantenimientos.proximos, 'mantenimiento-proximo'),
        ],
      ),
    );
  }

  /// Bloque de alertas de inventario (US6): total con la regla `stockBajo`
  /// y las refacciones en alerta con su faltante (FR-011).
  Widget _bloqueAlertas(DashboardInventoryBlock alertas) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;

    if (alertas.stockBajo == 0) {
      return EmptyView(
        key: const Key('alertas-vacio'),
        mensaje: 'No hay refacciones con stock bajo.',
      );
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Inventario', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          DetailRow(
            key: const Key('valor-stock-bajo'),
            label: 'Stock bajo',
            value: '${alertas.stockBajo}',
          ),
          if (alertas.refacciones.isNotEmpty) ...<Widget>[
            Text(
              'Refacciones en alerta',
              style: textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            for (final DashboardLowStockLine refaccion in alertas.refacciones)
              Padding(
                key: Key('alerta-${refaccion.id}'),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${refaccion.codigo} · ${refaccion.nombre}',
                            style: textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Stock: ${refaccion.stockActual} / mínimo '
                            '${refaccion.stockMinimo}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const StockBajoChip(),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
