import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Diálogo con la aparición del sistema de diseño (200 ms, con la curva por
/// defecto de Material y respetando la preferencia de reducir movimiento).
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) {
  return Navigator.of(context).push<T>(
    DialogRoute<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      animationStyle: AnimationStyle(
        duration: motionOf(context, AppDuration.appear),
      ),
      builder: builder,
    ),
  );
}

/// Diálogo de confirmación obligatorio para acciones de salida o destructivas
/// (docs/design-system.md, sección 8.5). Devuelve `true` solo si el usuario
/// pulsa "Confirmar".
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String confirmarLabel = 'Confirmar',
  String cancelarLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final bool? result = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final MotorixColors colors = dialogContext.motorixColors;
      return AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelarLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: colors.danger,
                    foregroundColor: colors.surface,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmarLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Confirmación estándar para cerrar la sesión.
Future<bool> confirmLogout(BuildContext context) {
  return showConfirmDialog(
    context,
    titulo: 'Cerrar sesión',
    mensaje: '¿Seguro que quieres cerrar la sesión? '
        'Perderás el acceso a las pantallas protegidas.',
    destructive: true,
  );
}

/// Confirmación estándar para salir de un formulario con cambios sin guardar.
Future<bool> confirmDiscardChanges(BuildContext context) {
  return showConfirmDialog(
    context,
    titulo: 'Cambios sin guardar',
    mensaje: 'Tienes cambios sin guardar. ¿Quieres salir sin guardarlos?',
    confirmarLabel: 'Salir sin guardar',
    cancelarLabel: 'Seguir editando',
    destructive: true,
  );
}
