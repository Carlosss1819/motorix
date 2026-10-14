import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/app_user.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/providers/shell_provider.dart';
import 'package:motorix_client/screens/login_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_theme.dart';
import 'package:motorix_client/widgets/app_shell.dart';

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'el tema de Motorix se construye con Material 3 y los tokens del diseño',
    (WidgetTester tester) async {
      final ThemeData theme = AppTheme.light();

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, const Color(0xFF9B4F55));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F2F1));
      expect(theme.extension<MotorixColors>(), isNotNull);
      expect(theme.textTheme.bodyMedium?.fontSize, AppFontSizes.body);
      expect(theme.textTheme.titleMedium?.fontSize, AppFontSizes.section);
    },
  );

  testWidgets(
    'LoginScreen se renderiza dentro de MaterialApp y Provider',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(api: ApiClient()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Motorix'), findsOneWidget);
      expect(find.text('Usuario o correo'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
    },
  );

  testWidgets(
    'el shell muestra las secciones del rol administrador',
    (WidgetTester tester) async {
      // Altura de escritorio: la lista del rol admin (ahora con «Panel»,
      // US5) necesita más alto que el viewport por defecto de 600.
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShellProvider>(
              create: (_) => ShellProvider(initialWidth: 1440),
            ),
            ChangeNotifierProvider<AuthProvider>.value(
              value: _AuthFake(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AppShell(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Motorix'), findsOneWidget);
      expect(find.text('Inicio'), findsWidgets);
      // Sección «Panel» del administrador (US5, HU5-2).
      expect(find.text('Panel'), findsOneWidget);
      expect(find.text('Clientes'), findsOneWidget);
      expect(find.text('Vehículos'), findsOneWidget);
      expect(find.text('Usuarios'), findsOneWidget);
      expect(find.text('Mi cuenta'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('admin'), findsWidgets);
      expect(find.text('Administrador'), findsWidgets);
    },
  );
}

/// Sesión de prueba con un administrador, sin tocar la red.
class _AuthFake extends AuthProvider {
  _AuthFake() : super(api: ApiClient());

  @override
  bool get isAuthenticated => true;

  @override
  AppUser? get user => const AppUser(
        id: 1,
        username: 'admin',
        email: 'admin@motorix.local',
        rol: Rol.admin,
      );
}
