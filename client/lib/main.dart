import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'models/enums.dart';
import 'providers/auth_provider.dart';
import 'providers/clients_provider.dart';
import 'providers/service_orders_provider.dart';
import 'providers/shell_provider.dart';
import 'providers/users_provider.dart';
import 'providers/vehicles_provider.dart';
import 'screens/account_screen.dart';
import 'screens/client_detail_screen.dart';
import 'screens/client_form_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/service_order_detail_screen.dart';
import 'screens/service_order_form_screen.dart';
import 'screens/service_orders_screen.dart';
import 'screens/users_screen.dart';
import 'screens/vehicle_detail_screen.dart';
import 'screens/vehicle_form_screen.dart';
import 'screens/vehicles_screen.dart';
import 'services/api_client.dart';
import 'utils/app_routes.dart';
import 'utils/app_theme.dart';
import 'utils/messages.dart';
import 'widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MotorixApp());
}

/// Aplicación de Motorix: MultiProvider, rutas protegidas y cierre de sesión
/// por inactividad (30 minutos).
class MotorixApp extends StatefulWidget {
  const MotorixApp({super.key});

  @override
  State<MotorixApp> createState() => _MotorixAppState();
}

class _MotorixAppState extends State<MotorixApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final ApiClient _api = ApiClient();

  /// Ancho de la ventana al arrancar: por debajo de 1000 px el sidebar
  /// comienza colapsado.
  double? get _anchoInicial {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) {
      return null;
    }
    return view.physicalSize.width / view.devicePixelRatio;
  }

  void _onSessionClosed(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        Routes.login,
        (Route<dynamic> route) => false,
      );
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ShellProvider>(
          create: (_) => ShellProvider(initialWidth: _anchoInicial),
        ),
        ChangeNotifierProvider<AuthProvider>(
          lazy: false,
          create: (_) {
            final AuthProvider auth = AuthProvider(api: _api);
            auth.onSessionClosed = _onSessionClosed;
            return auth;
          },
        ),
        ChangeNotifierProvider<ClientsProvider>(
          create: (_) => ClientsProvider(api: _api),
        ),
        ChangeNotifierProvider<VehiclesProvider>(
          create: (_) => VehiclesProvider(api: _api),
        ),
        ChangeNotifierProvider<ServiceOrdersProvider>(
          create: (_) => ServiceOrdersProvider(api: _api),
        ),
        ChangeNotifierProvider<UsersProvider>(
          create: (_) => UsersProvider(api: _api),
        ),
      ],
      child: Builder(
        builder: (BuildContext context) {
          return MaterialApp(
            title: 'Motorix',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            navigatorKey: _navigatorKey,
            scaffoldMessengerKey: _messengerKey,
            onGenerateRoute: (RouteSettings settings) =>
                _generateRoute(context, settings),
          );
        },
      ),
    );
  }

  /// Genera las rutas de la aplicación con acceso protegido: sin sesión se
  /// redirige al inicio de sesión.
  Route<dynamic> _generateRoute(BuildContext context, RouteSettings settings) {
    final String name = settings.name ?? Routes.home;
    final AuthProvider auth = context.read<AuthProvider>();

    Widget page;
    if (name == Routes.login) {
      page = auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
    } else if (!auth.isAuthenticated) {
      page = const LoginScreen();
    } else {
      page = _pageForRoute(
        name,
        settings,
        auth.user?.rol ?? Rol.mechanic,
      );
    }

    return AppPageRoute<dynamic>(
      settings: settings,
      builder: (_) => page,
    );
  }

  Widget _pageForRoute(String name, RouteSettings settings, String rol) {
    if (!_puedeAcceder(name, rol)) {
      return const AppShell(child: _SinPermisoScreen());
    }

    final Widget contenido = switch (name) {
      Routes.home => const HomeScreen(),
      Routes.clients => const ClientsScreen(),
      Routes.clientNew => ClientFormScreen(client: _arg<ClientFormArgs>(settings)?.client),
      Routes.clientDetail =>
        ClientDetailScreen(clientId: _arg<ClientDetailArgs>(settings)?.clientId ?? 0),
      Routes.clientEdit => ClientFormScreen(client: _arg<ClientFormArgs>(settings)?.client),
      Routes.vehicles => const VehiclesScreen(),
      Routes.vehicleNew => VehicleFormScreen(
          vehicle: _arg<VehicleFormArgs>(settings)?.vehicle,
          clienteId: _arg<VehicleFormArgs>(settings)?.clienteId,
        ),
      Routes.vehicleDetail =>
        VehicleDetailScreen(vehicleId: _arg<VehicleDetailArgs>(settings)?.vehicleId ?? 0),
      Routes.vehicleEdit => VehicleFormScreen(vehicle: _arg<VehicleFormArgs>(settings)?.vehicle),
      Routes.serviceOrders => const ServiceOrdersScreen(),
      Routes.serviceOrderNew => const ServiceOrderFormScreen(),
      Routes.serviceOrderDetail =>
        ServiceOrderDetailScreen(
          orderId: _arg<ServiceOrderDetailArgs>(settings)?.orderId ?? 0,
        ),
      Routes.users => const UsersScreen(),
      Routes.account => const AccountScreen(),
      _ => const HomeScreen(),
    };

    return AppShell(child: contenido);
  }

  static T? _arg<T>(RouteSettings settings) {
    return settings.arguments is T ? settings.arguments as T : null;
  }

  /// Ocultar no es seguridad: el backend vuelve a validar cada operación
  /// (FR-006 / RN-15).
  static bool _puedeAcceder(String route, String rol) {
    switch (route) {
      case Routes.clients:
      case Routes.clientNew:
      case Routes.clientDetail:
      case Routes.clientEdit:
      case Routes.vehicles:
      case Routes.vehicleNew:
      case Routes.vehicleDetail:
      case Routes.vehicleEdit:
      case Routes.serviceOrders:
      case Routes.serviceOrderNew:
      case Routes.serviceOrderDetail:
        return rol == Rol.admin || rol == Rol.receptionist;
      case Routes.users:
        return rol == Rol.admin;
      default:
        return true;
    }
  }
}

/// Aviso de sección no permitida para el rol actual.
class _SinPermisoScreen extends StatelessWidget {
  const _SinPermisoScreen();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppMetrics.contentMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Sección no disponible', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text(AppMessages.noPermission, style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, Routes.home),
              icon: const Icon(
                LucideIcons.house,
                size: AppMetrics.iconSizeSmall,
              ),
              label: const Text('Ir a Inicio'),
            ),
          ],
        ),
      ),
    );
  }
}
