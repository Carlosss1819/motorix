import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../providers/auth_provider.dart';
import '../providers/shell_provider.dart';
import '../utils/app_routes.dart';
import '../utils/app_theme.dart';
import 'confirm_dialog.dart';

/// Una sección del sidebar.
class ShellSection {
  const ShellSection({
    required this.route,
    required this.icon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final String label;
}

/// Secciones del sidebar del Sprint 1 y sus títulos.
abstract final class ShellSections {
  static const ShellSection home = ShellSection(
    route: Routes.home,
    icon: LucideIcons.house,
    label: 'Inicio',
  );
  static const ShellSection clients = ShellSection(
    route: Routes.clients,
    icon: LucideIcons.users,
    label: 'Clientes',
  );
  static const ShellSection vehicles = ShellSection(
    route: Routes.vehicles,
    icon: LucideIcons.carFront,
    label: 'Vehículos',
  );
  static const ShellSection appointments = ShellSection(
    route: Routes.appointments,
    icon: LucideIcons.calendar,
    label: 'Citas',
  );
  static const ShellSection orders = ShellSection(
    route: Routes.serviceOrders,
    icon: LucideIcons.wrench,
    label: 'Órdenes',
  );
  static const ShellSection myOrders = ShellSection(
    route: Routes.myOrders,
    icon: LucideIcons.clipboardList,
    label: 'Mis órdenes',
  );
  static const ShellSection users = ShellSection(
    route: Routes.users,
    icon: LucideIcons.userCog,
    label: 'Usuarios',
  );
  static const ShellSection account = ShellSection(
    route: Routes.account,
    icon: LucideIcons.circleUser,
    label: 'Mi cuenta',
  );

  /// Secciones visibles para cada rol. Ocultar no es seguridad: el backend
  /// valida cada operación protegida (RN-15).
  static List<ShellSection> forRole(String rol) {
    return switch (rol) {
      Rol.admin =>
        const <ShellSection>[
          home,
          clients,
          vehicles,
          appointments,
          orders,
          users,
          account,
        ],
      Rol.receptionist =>
        const <ShellSection>[
          home,
          clients,
          vehicles,
          appointments,
          orders,
          account,
        ],
      Rol.mechanic => const <ShellSection>[home, myOrders, account],
      _ => const <ShellSection>[home, account],
    };
  }

  /// Título de la sección según la ruta actual.
  static String titleForRoute(String? route) {
    return switch (route) {
      Routes.home => 'Inicio',
      Routes.reception => 'Panel de recepción',
      Routes.clients => 'Clientes',
      Routes.clientNew => 'Nuevo cliente',
      Routes.clientDetail => 'Detalle de cliente',
      Routes.clientEdit => 'Editar cliente',
      Routes.vehicles => 'Vehículos',
      Routes.vehicleNew => 'Nuevo vehículo',
      Routes.vehicleDetail => 'Detalle de vehículo',
      Routes.vehicleEdit => 'Editar vehículo',
      Routes.appointments => 'Citas',
      Routes.appointmentNew => 'Nueva cita',
      Routes.appointmentEdit => 'Editar cita',
      Routes.serviceOrders => 'Órdenes',
      Routes.myOrders => 'Mis órdenes',
      Routes.serviceOrderNew => 'Nueva orden',
      Routes.serviceOrderDetail => 'Detalle de orden',
      Routes.users => 'Usuarios',
      Routes.account => 'Mi cuenta',
      _ => 'Motorix',
    };
  }

  /// Pista de búsqueda del header para las secciones con lista.
  static String searchHintForRoute(String? route) {
    return switch (route) {
      Routes.clients => SearchHints.clients,
      Routes.vehicles => SearchHints.vehicles,
      Routes.users => SearchHints.users,
      Routes.appointments => SearchHints.appointments,
      Routes.serviceOrders => SearchHints.orders,
      Routes.myOrders => SearchHints.orders,
      _ => '',
    };
  }
}

/// Estructura general de la aplicación: sidebar colapsable, header con título,
/// buscador, usuario y rol, y el contenido de la sección actual.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final TextEditingController _searchController;
  String _hint = '';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    final String? routeName = ModalRoute.of(context)?.settings.name;
    _hint = ShellSections.searchHintForRoute(routeName);
    _searchController = TextEditingController(
      text: context.read<ShellProvider>().queryFor(_hint),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShellProvider shell = context.watch<ShellProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final String? routeName = ModalRoute.of(context)?.settings.name;
    final List<ShellSection> sections =
        ShellSections.forRole(auth.user?.rol ?? Rol.mechanic);
    final int selected =
        sections.indexWhere((ShellSection section) => section.route == routeName);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Sidebar(
            expanded: shell.expanded,
            sections: sections,
            selectedIndex: selected >= 0 ? selected : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(
                  title: ShellSections.titleForRoute(routeName),
                  hint: _hint,
                  controller: _searchController,
                ),
                Divider(),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.expanded,
    required this.sections,
    required this.selectedIndex,
  });

  final bool expanded;
  final List<ShellSection> sections;
  final int? selectedIndex;

  void _goToSection(BuildContext context, String route) {
    final String? current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (Route<dynamic> route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ShellProvider shell = context.watch<ShellProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final MotorixColors colors = context.motorixColors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: motionOf(context, AppDuration.appear),
      curve: Curves.easeInOut,
      width: expanded
          ? AppMetrics.sidebarExpandedWidth
          : AppMetrics.sidebarCollapsedWidth,
      color: colors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: shell.toggle,
                  tooltip: expanded ? 'Contraer menú' : 'Expandir menú',
                  style: IconButton.styleFrom(
                    foregroundColor: colors.sidebarTextMuted,
                    hoverColor: colors.sidebarActive,
                    highlightColor: colors.sidebarActive,
                  ),
                  icon: Icon(
                    expanded ? LucideIcons.chevronsLeft : LucideIcons.chevronsRight,
                    size: AppMetrics.iconSize,
                  ),
                ),
                if (expanded) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Motorix',
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.sidebarText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: NavigationRail(
              extended: expanded,
              minWidth: AppMetrics.sidebarCollapsedWidth,
              minExtendedWidth: AppMetrics.sidebarExpandedWidth,
              backgroundColor: colors.sidebar,
              useIndicator: true,
              indicatorColor: colors.sidebarActive,
              selectedIndex: selectedIndex,
              labelType: NavigationRailLabelType.none,
              onDestinationSelected: (int index) =>
                  _goToSection(context, sections[index].route),
              destinations: <NavigationRailDestination>[
                for (final ShellSection section in sections)
                  NavigationRailDestination(
                    icon: expanded
                        ? Icon(section.icon)
                        : Tooltip(
                            message: section.label,
                            child: Icon(section.icon),
                          ),
                    label: Text(section.label),
                  ),
              ],
            ),
          ),
          _SidebarFooter(expanded: expanded, auth: auth, colors: colors),
        ],
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.expanded,
    required this.auth,
    required this.colors,
  });

  final bool expanded;
  final AuthProvider auth;
  final MotorixColors colors;

  Future<void> _logout(BuildContext context) async {
    final bool confirmed = await confirmLogout(context);
    if (!confirmed || !context.mounted) {
      return;
    }
    await context.read<AuthProvider>().logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.login,
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget content = expanded
        ? Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  auth.user?.username ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.sidebarText,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  auth.user?.rolLabel ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.sidebarTextMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.sidebarText,
                    side: BorderSide(color: colors.sidebarTextMuted),
                    alignment: Alignment.centerLeft,
                  ),
                  icon: const Icon(
                    LucideIcons.logOut,
                    size: AppMetrics.iconSizeSmall,
                  ),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: IconButton(
              onPressed: () => _logout(context),
              tooltip: 'Cerrar sesión',
              style: IconButton.styleFrom(
                foregroundColor: colors.sidebarTextMuted,
                hoverColor: colors.sidebarActive,
                highlightColor: colors.sidebarActive,
              ),
              icon: const Icon(
                LucideIcons.logOut,
                size: AppMetrics.iconSize,
              ),
            ),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Divider(color: colors.sidebarActive),
        content,
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.hint,
    required this.controller,
  });

  final String title;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final MotorixColors colors = context.motorixColors;
    final AuthProvider auth = context.watch<AuthProvider>();
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              title,
              style: textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          if (hint.isNotEmpty)
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppMetrics.headerSearchWidth,
                ),
                child: TextField(
                  controller: controller,
                  onChanged: (String value) =>
                      context.read<ShellProvider>().setQuery(hint, value),
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      size: AppMetrics.iconSizeSmall,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.xl),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                auth.user?.username ?? '',
                style: textTheme.labelMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                auth.user?.rolLabel ?? '',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
