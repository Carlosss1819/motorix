import 'package:flutter/material.dart';

import '../models/payment.dart';
import '../utils/app_theme.dart';

/// Color del estado de un pago según docs/design-system.md: verde el cobro
/// aprobado, ámbar el pendiente de confirmación, rojo el rechazado y neutros
/// los estados finales que solo quedan como historial (cancelado/anulado).
Color _colorFor(BuildContext context, String estado) {
  final MotorixColors colors = context.motorixColors;
  switch (estado) {
    case 'PAGADO':
      return colors.success;
    case 'PENDIENTE':
      return colors.warning;
    case 'RECHAZADO':
      return colors.danger;
    default: // CANCELADO y ANULADO
      return colors.textSecondary;
  }
}

/// Chip del estado de un pago (HU1, D7): fondo suave y texto en el color de
/// estado, con el mismo estilo que los chips de orden y cita.
class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({super.key, required this.estado});

  /// Estado tal como lo devuelve la API (`PAGADO`, `PENDIENTE`…).
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
        paymentStatusLabel(estado),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
