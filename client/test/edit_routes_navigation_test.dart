import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/app_user.dart';
import 'package:motorix_client/models/appointment.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/models/maintenance.dart';
import 'package:motorix_client/models/part.dart';
import 'package:motorix_client/providers/appointments_provider.dart';
import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/providers/maintenance_provider.dart';
import 'package:motorix_client/providers/parts_provider.dart';
import 'package:motorix_client/providers/shell_provider.dart';
import 'package:motorix_client/screens/appointments_screen.dart';
import 'package:motorix_client/screens/maintenance_screen.dart';
import 'package:motorix_client/screens/parts_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/appointments_service.dart';
import 'package:motorix_client/services/maintenance_service.dart';
import 'package:motorix_client/services/parts_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

/// Servicio falso de citas: devuelve una cita PROGRAMADA en memoria.
class _AppointmentsServiceFake extends AppointmentsService {
  _AppointmentsServiceFake() : super(ApiClient());

  @override
  Future<AppointmentPage> list({
    String fecha = '',
    String desde = '',
    String hasta = '',
    String estado = '',
    String buscar = '',
    int pagina = 1,
    int porPagina = 10,
  }) async {
    return const AppointmentPage(
      elementos: <Appointment>[
        Appointment(
          id: 1,
          clienteId: 1,
          cliente: 'Juan Pérez',
          vehiculoId: 1,
          vehiculo: 'Nissan Versa 2020',
          placas: 'ABC1234',
          fecha: '2026-10-14',
          hora: '10:00',
          motivo: 'Cambio de aceite',
          estado: 'PROGRAMADA',
        ),
      ],
      pagina: 1,
      paginas: 1,
      total: 1,
    );
  }
}

/// Servicio falso de mantenimientos: devuelve un mantenimiento NORMAL.
class _MaintenanceServiceFake extends MaintenanceService {
  _MaintenanceServiceFake() : super(ApiClient());

  @override
  Future<MaintenancePage> list({
    int? vehiculoId,
    String estado = '',
    String buscar = '',
    int pagina = 1,
    int porPagina = 10,
  }) async {
    return const MaintenancePage(
      elementos: <Maintenance>[
        Maintenance(
          id: 1,
          vehiculoId: 1,
          vehiculo: 'Nissan Versa 2020',
          placas: 'ABC1234',
          cliente: 'Juan Pérez',
          tipoServicio: 'Cambio de aceite',
          fechaUltimoServicio: '2026-07-01',
          kilometrajeUltimoServicio: 40000,
          fechaObjetivo: '2026-12-31',
          kilometrajeObjetivo: 45000,
          intervaloDias: 90,
          intervaloKm: 5000,
          antelacionDias: 30,
          antelacionKm: 500,
          notas: null,
          estado: 'NORMAL',
        ),
      ],
      pagina: 1,
      paginas: 1,
      total: 1,
    );
  }
}

/// Servicio falso de inventario: devuelve una refacción activa.
class _PartsServiceFake extends PartsService {
  _PartsServiceFake() : super(ApiClient());

  @override
  Future<PartPage> list({
    String buscar = '',
    bool stockBajo = false,
    bool? activa,
    int pagina = 1,
    int porPagina = 10,
  }) async {
    return const PartPage(
      elementos: <Part>[
        Part(
          id: 1,
          codigo: 'PAD-001',
          nombre: 'Juego de pastillas delanteras',
          categoria: 'Frenos',
          marca: 'Brembo',
          stockActual: 3,
          stockMinimo: 5,
          stockBajo: true,
          precioCompra: 180,
          precioVenta: 320,
          activa: true,
        ),
      ],
      pagina: 1,
      paginas: 1,
      total: 1,
    );
  }
}

/// Sesión de prueba de administrador, sin tocar la red.
class _AuthFake extends AuthProvider {
  _AuthFake() : super(api: ApiClient());

  @override
  bool get isAuthenticated => true;

  @override
  AppUser? get user => AppUser(
        id: 1,
        username: 'prueba',
        email: 'prueba@motorix.local',
        rol: Rol.admin,
      );
}

/// Bombea la pantalla dentro de un `MaterialApp` cuyo `onGenerateRoute`
/// devuelve rutas `Route<Object?>`, igual que el de la app real (que devuelve
/// `AppPageRoute<dynamic>`). Regresión del fallo de `pushNamed<bool>`: el
/// cast de la ruta generada a `Route<bool>` revienta en tiempo de ejecución
/// y la navegación moría en silencio.
Future<void> _pumpConRuta(
  WidgetTester tester, {
  required Widget pantalla,
  required List<ChangeNotifierProvider<ChangeNotifier?>> proveedores,
  required String rutaEdicion,
  required String marcador,
}) async {
  tester.view.physicalSize = const Size(1280, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: proveedores,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: pantalla),
        onGenerateRoute: (RouteSettings settings) {
          if (settings.name == rutaEdicion) {
            return MaterialPageRoute<Object?>(
              builder: (_) => Scaffold(body: Text(marcador)),
            );
          }
          return null;
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

List<ChangeNotifierProvider<ChangeNotifier?>> _proveedoresBase() {
  return <ChangeNotifierProvider<ChangeNotifier?>>[
    ChangeNotifierProvider<ShellProvider>(
      create: (_) => ShellProvider(initialWidth: 1440),
    ),
    ChangeNotifierProvider<AuthProvider>.value(value: _AuthFake()),
  ];
}

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'Citas: tocar el lápiz «Editar» abre la ruta de edición',
    (WidgetTester tester) async {
      await _pumpConRuta(
        tester,
        pantalla: const AppointmentsScreen(),
        proveedores: <ChangeNotifierProvider<ChangeNotifier?>>[
          ..._proveedoresBase(),
          ChangeNotifierProvider<AppointmentsProvider>(
            create: (_) => AppointmentsProvider(
              api: ApiClient(),
              service: _AppointmentsServiceFake(),
            ),
          ),
        ],
        rutaEdicion: '/appointments/edit',
        marcador: 'FORMULARIO_EDICION_CITA',
      );

      await tester.tap(find.byTooltip('Editar cita'));
      await tester.pumpAndSettle();

      expect(
        find.text('FORMULARIO_EDICION_CITA'),
        findsOneWidget,
        reason: 'el lápiz de Citas debe navegar al formulario de edición',
      );
    },
  );

  testWidgets(
    'Mantenimientos: tocar el lápiz «Editar» abre la ruta de edición',
    (WidgetTester tester) async {
      await _pumpConRuta(
        tester,
        pantalla: const MaintenanceScreen(),
        proveedores: <ChangeNotifierProvider<ChangeNotifier?>>[
          ..._proveedoresBase(),
          ChangeNotifierProvider<MaintenanceProvider>(
            create: (_) => MaintenanceProvider(
              api: ApiClient(),
              service: _MaintenanceServiceFake(),
            ),
          ),
        ],
        rutaEdicion: '/maintenance/edit',
        marcador: 'FORMULARIO_EDICION_MANTENIMIENTO',
      );

      await tester.tap(find.byTooltip('Editar mantenimiento'));
      await tester.pumpAndSettle();

      expect(
        find.text('FORMULARIO_EDICION_MANTENIMIENTO'),
        findsOneWidget,
        reason: 'el lápiz de Mantenimientos debe navegar al formulario',
      );
    },
  );

  testWidgets(
    'Inventario: tocar el lápiz «Editar» abre la ruta de edición',
    (WidgetTester tester) async {
      await _pumpConRuta(
        tester,
        pantalla: const PartsScreen(),
        proveedores: <ChangeNotifierProvider<ChangeNotifier?>>[
          ..._proveedoresBase(),
          ChangeNotifierProvider<PartsProvider>(
            create: (_) => PartsProvider(
              api: ApiClient(),
              service: _PartsServiceFake(),
            ),
          ),
        ],
        rutaEdicion: '/parts/edit',
        marcador: 'FORMULARIO_EDICION_REFACCION',
      );

      await tester.tap(find.byTooltip('Editar refacción'));
      await tester.pumpAndSettle();

      expect(
        find.text('FORMULARIO_EDICION_REFACCION'),
        findsOneWidget,
        reason: 'el lápiz de Inventario debe navegar al formulario',
      );
    },
  );
}
