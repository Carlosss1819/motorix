import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../utils/app_theme.dart';

/// Panel contenedor con el estilo de panel del sistema de diseño (fondo
/// blanco, borde fino y radio de 8).
class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.expand = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Ocupa todo el ancho disponible.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    return Container(
      width: expand ? double.infinity : null,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: colors.outline),
      ),
      child: child,
    );
  }
}

/// Estado de carga: indicador discreto centrado.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.mensaje = 'Cargando…'});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(mensaje, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Estado de error: mensaje claro en español, sin trazas internas.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.mensaje, this.onRetry});

  final String mensaje;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: AppPanel(
          expand: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(LucideIcons.triangleAlert, color: colors.danger, size: AppSpacing.xxl),
              const SizedBox(height: AppSpacing.md),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colors.danger),
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(LucideIcons.refreshCw, size: AppMetrics.iconSizeSmall),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío: mensaje útil y acción sugerida.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.mensaje,
    this.actionLabel,
    this.onAction,
  });

  final String mensaje;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: AppPanel(
          expand: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(mensaje, textAlign: TextAlign.center, style: textTheme.bodyMedium),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(LucideIcons.plus, size: AppMetrics.iconSizeSmall),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso breve de error dentro de un formulario.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: colors.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(LucideIcons.triangleAlert, color: colors.danger, size: AppMetrics.iconSizeSmall),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip de estado activo/inactivo.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final Color color = activo ? colors.success : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: activo ? colors.successSoft : colors.background,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// Fila de una ficha de detalle: etiqueta y valor.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value, this.onTap});

  final String label;
  final String value;

  /// Si se define, la fila se vuelve pulsable (por ejemplo, para abrir el
  /// propietario de un vehículo).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: AppMetrics.detailLabelWidth,
            child: Text(label, style: textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null)
            const Icon(
              LucideIcons.chevronRight,
              size: AppMetrics.iconSizeSmall,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: content,
    );
  }
}

/// Botón "Volver" para las pantallas de detalle y de formulario.
class BackAction extends StatelessWidget {
  const BackAction({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.maybePop(context),
      icon: const Icon(LucideIcons.arrowLeft, size: AppMetrics.iconSizeSmall),
      label: const Text('Volver'),
    );
  }
}

/// Botones de un formulario: secundario a la izquierda y principal a la
/// derecha (docs/design-system.md, sección 8.3).
class FormActions extends StatelessWidget {
  const FormActions({
    super.key,
    required this.onCancel,
    required this.onSave,
    required this.saveLabel,
    this.saving = false,
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        OutlinedButton(
          onPressed: saving ? null : onCancel,
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? SizedBox(
                  width: AppMetrics.spinnerSize,
                  height: AppMetrics.spinnerSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.surface,
                  ),
                )
              : const Icon(LucideIcons.check, size: AppMetrics.iconSizeSmall),
          label: Text(saveLabel),
        ),
      ],
    );
  }
}
