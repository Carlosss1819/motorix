import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Etiqueta en español de un estado de orden o de cita.
String orderStatusLabel(String estado) {
  switch (estado) {
    case 'RECIBIDO':
      return 'Recibido';
    case 'DIAGNOSTICO':
      return 'Diagnóstico';
    case 'EN_REPARACION':
      return 'En reparación';
    case 'ESPERANDO_REFACCION':
      return 'Esperando refacción';
    case 'TERMINADO':
      return 'Terminado';
    case 'ENTREGADO':
      return 'Entregado';
    case 'PROGRAMADA':
      return 'Programada';
    case 'RECIBIDA':
      return 'Recibida';
    case 'CANCELADA':
      return 'Cancelada';
    case 'NO_PRESENTADA':
      return 'No presentada';
    default:
      return estado;
  }
}

/// Color de estado según docs/design-system.md: verde completado, ámbar
/// advertencia o próximo, rojo error o vencido; el resto, neutros o de marca.
Color _colorFor(BuildContext context, String estado) {
  final MotorixColors colors = context.motorixColors;
  switch (estado) {
    case 'TERMINADO':
    case 'ENTREGADO':
    case 'RECIBIDA':
      return colors.success;
    case 'ESPERANDO_REFACCION':
    case 'NO_PRESENTADA':
      return colors.warning;
    case 'CANCELADA':
      return colors.danger;
    case 'EN_REPARACION':
      return colors.primary;
    case 'DIAGNOSTICO':
      return colors.textPrimary;
    default: // RECIBIDO, PROGRAMADA y estados desconocidos
      return colors.textSecondary;
  }
}

/// Chip genérico de estado (orden o cita) construido con los tokens del
/// sistema de diseño: fondo suave y texto en el color de estado.
class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.estado});

  /// Valor del estado tal como lo devuelve la API (`RECIBIDO`, `PROGRAMADA`…).
  final String estado;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final Color color = _colorFor(context, estado);
    final bool esNeutro = color == colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: esNeutro ? colors.background : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        orderStatusLabel(estado),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// Chip del estado de una orden de servicio.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) => EstadoChip(estado: estado);
}

/// Chip del estado de una cita de recepción.
class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) => EstadoChip(estado: estado);
}
