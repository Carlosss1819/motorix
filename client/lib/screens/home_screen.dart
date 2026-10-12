import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/auth_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/common_views.dart';

/// Inicio (bienvenida) con el usuario y el rol de la sesión (FR-021).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String username = auth.user?.username ?? '';
    final String rolLabel =
        Rol.label(auth.user?.rol ?? Rol.mechanic);
    final List<ShellSection> sections =
        ShellSections.forRole(auth.user?.rol ?? Rol.mechanic);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              username.isEmpty ? 'Bienvenido' : 'Bienvenido, $username',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Rol: $rolLabel',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('¿Qué quieres hacer hoy?', style: textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Estos son los módulos disponibles para tu rol en este '
                    'momento. Cualquier operación se valida también en el '
                    'servidor.',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final ShellSection section in sections)
                        if (section.route != Routes.home)
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              section.route,
                            ),
                            icon: Icon(
                              section.icon,
                              size: AppMetrics.iconSizeSmall,
                            ),
                            label: Text(section.label),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
