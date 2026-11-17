import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/notification.dart';
import '../providers/load_status.dart';
import '../providers/notifications_provider.dart';
import '../screens/appointments_screen.dart';
import '../screens/part_detail_screen.dart';
import '../screens/service_order_detail_screen.dart';
import '../screens/vehicle_detail_screen.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import 'common_views.dart';
import 'confirm_dialog.dart';

/// Texto de la insignia: el número, o «99+» si hay más de 99.
String notificationBadgeText(int noLeidos) => noLeidos > 99 ? '99+' : '$noLeidos';

/// Campana del encabezado (Sprint 6, US1; contracts/ui-flutter.md): visible
/// para los tres roles, con la insignia de no leídos. El contador se pide al
/// crearse (el encabezado se arma de nuevo en cada sección: inicio de sesión y
/// cada cambio de sección, FR-017). Sin temporizador.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

/// El provider de avisos, o `null` si el árbol no lo registra (por ejemplo,
/// pruebas de pantallas anteriores al Sprint 6 que arman el `AppShell` sin
/// él): en ese caso la campana no se muestra en lugar de fallar.
NotificationsProvider? _maybeNotifications(BuildContext context, {bool listen = false}) {
  try {
    return Provider.of<NotificationsProvider>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeNotifications(context)?.refreshCount();
      }
    });
  }

  Future<void> _abrirPanel() async {
    final NotificationsProvider avisos = context.read<NotificationsProvider>();
    avisos.load();
    final NotificationItem? elegido = await showAppDialog<NotificationItem>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => const NotificationsPanelDialog(),
    );
    if (elegido == null || !mounted) {
      return;
    }
    // Tocar un aviso lo marca como leído (M1) y abre su pantalla.
    await avisos.markRead(elegido);
    if (!mounted) {
      return;
    }
    openNotificationTarget(context, elegido.destino);
  }

  @override
  Widget build(BuildContext context) {
    final NotificationsProvider? avisos = _maybeNotifications(context, listen: true);
    if (avisos == null) {
      return const SizedBox.shrink();
    }
    final int noLeidos = avisos.noLeidos;
    final MotorixColors colors = context.motorixColors;
    final Widget icono = Icon(LucideIcons.bell, size: AppMetrics.iconSize);
    return IconButton(
      key: const Key('notification-bell'),
      tooltip: noLeidos > 0 ? 'Avisos ($noLeidos sin leer)' : 'Avisos',
      onPressed: _abrirPanel,
      icon: noLeidos > 0
          ? Badge(
              key: const Key('notification-badge'),
              backgroundColor: colors.danger,
              label: Text(notificationBadgeText(noLeidos)),
              child: icono,
            )
          : icono,
    );
  }
}

/// Abre la pantalla del destino de un aviso.
void openNotificationTarget(BuildContext context, NotificationTarget destino) {
  switch (destino.pantalla) {
    case NotificationScreens.orden:
      Navigator.pushNamed(
        context,
        Routes.serviceOrderDetail,
        arguments: ServiceOrderDetailArgs(orderId: destino.id),
      );
    case NotificationScreens.citas:
      Navigator.pushNamed(
        context,
        Routes.appointments,
        arguments: AppointmentsArgs(fecha: destino.fecha),
      );
    case NotificationScreens.vehiculo:
      Navigator.pushNamed(
        context,
        Routes.vehicleDetail,
        arguments: VehicleDetailArgs(vehicleId: destino.id),
      );
    case NotificationScreens.refaccion:
      Navigator.pushNamed(
        context,
        Routes.partDetail,
        arguments: PartDetailArgs(refaccionId: destino.id),
      );
  }
}

/// Color semántico de cada tipo (contrato de interfaz): `danger` para
/// vencido, agotado y orden detenida; `warning` para stock bajo y próximo;
/// el color informativo (primario) para la cita de hoy.
Color notificationColor(MotorixColors colors, String tipo) {
  return switch (tipo) {
    NotificationTypes.mantVencido ||
    NotificationTypes.stockAgotado ||
    NotificationTypes.ordenDetenida =>
      colors.danger,
    NotificationTypes.stockBajo || NotificationTypes.mantProximo => colors.warning,
    _ => colors.primary,
  };
}

/// Panel de avisos en un diálogo: carga, vacío, error y grupos. Devuelve el
/// aviso tocado (o nada si se cierra).
class NotificationsPanelDialog extends StatelessWidget {
  const NotificationsPanelDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationsProvider avisos = context.watch<NotificationsProvider>();
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget contenido = switch (avisos.status) {
      LoadStatus.error => ErrorView(
          mensaje: avisos.error ?? 'No se pudieron cargar los avisos',
          onRetry: avisos.load,
        ),
      LoadStatus.ready when (avisos.resumen?.grupos.isEmpty ?? true) =>
        const EmptyView(mensaje: 'No tienes avisos pendientes'),
      LoadStatus.ready => _NotificationGroupsList(resumen: avisos.resumen!),
      _ => const LoadingView(mensaje: 'Cargando avisos…'),
    };

    return Dialog(
      key: const Key('notifications-panel'),
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text('Avisos', style: textTheme.titleMedium)),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: AppMetrics.iconSizeSmall),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: contenido,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationGroupsList extends StatelessWidget {
  const _NotificationGroupsList({required this.resumen});

  final NotificationsSummary resumen;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MotorixColors colors = context.motorixColors;
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        for (final NotificationGroup grupo in resumen.grupos) ...<Widget>[
          Padding(
            key: Key('grupo-${grupo.tipo}'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Text(
              '${grupo.titulo} (${grupo.cantidad})',
              style: textTheme.labelLarge?.copyWith(
                color: notificationColor(colors, grupo.tipo),
              ),
            ),
          ),
          for (final NotificationItem aviso in grupo.avisos)
            _NotificationTile(aviso: aviso),
        ],
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.aviso});

  final NotificationItem aviso;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color color = notificationColor(colors, aviso.tipo);
    final String fecha = aviso.fechaReferencia.replaceFirst('T', ' ');

    return Opacity(
      // Los leídos se ven atenuados (contrato de interfaz).
      opacity: aviso.leido ? 0.6 : 1,
      child: ListTile(
        key: Key('aviso-${aviso.clave}'),
        dense: true,
        onTap: () => Navigator.of(context).pop(aviso),
        leading: Icon(
          aviso.leido ? LucideIcons.circle : LucideIcons.circleDot,
          color: color,
          size: AppMetrics.iconSizeSmall,
        ),
        title: Text(
          aviso.titulo,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: aviso.leido ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        subtitle: Text('${aviso.descripcion}\n$fecha'),
        isThreeLine: true,
        trailing: aviso.leido
            ? null
            : IconButton(
                key: Key('marcar-leido-${aviso.clave}'),
                tooltip: 'Marcar como leído',
                icon: const Icon(LucideIcons.check, size: AppMetrics.iconSizeSmall),
                onPressed: () => context.read<NotificationsProvider>().markRead(aviso),
              ),
      ),
    );
  }
}
