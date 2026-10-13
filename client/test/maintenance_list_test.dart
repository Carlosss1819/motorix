import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/app_user.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/models/maintenance.dart';
import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/providers/maintenance_provider.dart';
import 'package:motorix_client/providers/shell_provider.dart';
import 'package:motorix_client/screens/maintenance_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/maintenance_service.dart';
import 'package:motorix_client/utils/app_theme.dart';
import 'package:motorix_client/widgets/status_chip.dart';

/// Servicio falso con datos en memoria: no se abre ninguna conexión y se
/// registran los filtros enviados por la pantalla.
class _MaintenanceServiceFake extends MaintenanceService {
  _MaintenanceServiceFake({this.page, this.failure}) : super(ApiClient());

  /// Página que devuelve `list`.
  MaintenancePage? page;

  /// Si se define, `list` lanza este error.
  ApiException? failure;

  int listados = 0;
  final List<String> estadosConsultados = <String>[];
  final List<String> busquedasConsultadas = <String>[];

  @override
  Future<MaintenancePage> list({
    int? vehiculoId,
    String estado = '',
    String buscar = '',
    int pagina = 1,
    int porPagina = 10,
  }) async {
    listados += 1;
    estadosConsultados.add(estado);
    busquedasConsultadas.add(buscar);
    if (failure != null) {
      throw failure!;
    }
    return page ??
        const MaintenancePage(
          elementos: <Maintenance>[],
          pagina: 1,
          paginas: 1,
          total: 0,
        );
  }
}

/// Sesión de prueba con el rol indicado, sin tocar la red.
class _AuthFake extends AuthProvider {
  _AuthFake(this._rol) : super(api: ApiClient());

  final String _rol;

  @override
  bool get isAuthenticated => true;

  @override
  AppUser? get user => AppUser(
        id: 1,
        username: 'prueba',
        email: 'prueba@motorix.local',
        rol: _rol,
      );
}

/// Mantenimiento de ejemplo en estado NORMAL (con servicios previos).
const Maintenance _normal = Maintenance(
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
);

/// Mantenimiento de ejemplo PRÓXIMO solo por kilometraje y sin servicios.
const Maintenance _proximo = Maintenance(
  id: 2,
  vehiculoId: 2,
  vehiculo: 'Mazda CX-5 2022',
  placas: 'XYZ5678',
  cliente: 'María López',
  tipoServicio: 'Rotación de llantas',
  fechaUltimoServicio: '2026-06-15',
  kilometrajeUltimoServicio: null,
  fechaObjetivo: null,
  kilometrajeObjetivo: 80000,
  intervaloDias: null,
  intervaloKm: 10000,
  antelacionDias: 30,
  antelacionKm: 500,
  notas: null,
  estado: 'PROXIMO',
);

/// Mantenimiento de ejemplo VENCIDO, solo por fecha y nunca atendido.
const Maintenance _vencido = Maintenance(
  id: 3,
  vehiculoId: 3,
  vehiculo: 'Toyota Corolla 2019',
  placas: 'PPP9012',
  cliente: 'Carlos Ruiz',
  tipoServicio: 'Revisión de frenos',
  fechaUltimoServicio: null,
  kilometrajeUltimoServicio: null,
  fechaObjetivo: '2026-09-01',
  kilometrajeObjetivo: null,
  intervaloDias: 180,
  intervaloKm: null,
  antelacionDias: 30,
  antelacionKm: 500,
  notas: null,
  estado: 'VENCIDO',
);

const MaintenancePage _paginaConLosTresEstados = MaintenancePage(
  elementos: <Maintenance>[_normal, _proximo, _vencido],
  pagina: 1,
  paginas: 1,
  total: 3,
);

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required _MaintenanceServiceFake fake,
    ShellProvider? shell,
    String rol = Rol.admin,
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ShellProvider>(
            create: (_) => shell ?? ShellProvider(initialWidth: 1440),
          ),
          ChangeNotifierProvider<AuthProvider>.value(
            value: _AuthFake(rol),
          ),
          ChangeNotifierProvider<MaintenanceProvider>(
            create: (_) =>
                MaintenanceProvider(api: ApiClient(), service: fake),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: MaintenanceScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('MaintenanceScreen — lista de mantenimientos (US4/HU4)', () {
    testWidgets(
      'sin mantenimientos programados muestra el estado vacío (SC-003)',
      (WidgetTester tester) async {
        await pumpScreen(tester, fake: _MaintenanceServiceFake());

        expect(
          find.textContaining('No hay mantenimientos pendientes'),
          findsOneWidget,
        );
        expect(find.text('Cambio de aceite'), findsNothing);
      },
    );

    testWidgets(
      'cada tarjeta muestra tipo, vehículo, cliente, objetivo y su estado',
      (WidgetTester tester) async {
        final _MaintenanceServiceFake fake = _MaintenanceServiceFake(
          page: _paginaConLosTresEstados,
        );

        await pumpScreen(tester, fake: fake);

        // Los tres estados calculados se muestran con su chip (R-04).
        expect(find.byType(MaintenanceStatusChip), findsNWidgets(3));

        expect(find.text('Cambio de aceite'), findsOneWidget);
        expect(find.text('Rotación de llantas'), findsOneWidget);
        expect(find.text('Revisión de frenos'), findsOneWidget);

        // Vehículo, placas y cliente juntos (HU4: la llamada de seguimiento).
        expect(
          find.text('Nissan Versa 2020 · ABC1234 · Juan Pérez'),
          findsOneWidget,
        );
        expect(
          find.text('Mazda CX-5 2022 · XYZ5678 · María López'),
          findsOneWidget,
        );
        expect(
          find.text('Toyota Corolla 2019 · PPP9012 · Carlos Ruiz'),
          findsOneWidget,
        );

        // Último servicio: con fecha y km, solo con fecha, y sin registrar.
        expect(
          find.text('Último: 01/07/2026 · 40,000 km'),
          findsOneWidget,
        );
        expect(find.text('Último: 15/06/2026'), findsOneWidget);
        expect(find.text('Sin servicios registrados'), findsOneWidget);

        // Objetivo: por fecha y km, solo por km y solo por fecha.
        expect(
          find.text('Próximo: 31/12/2026 o 45,000 km'),
          findsOneWidget,
        );
        expect(find.text('Próximo: 80,000 km'), findsOneWidget);
        expect(find.text('Próximo: 01/09/2026'), findsOneWidget);

        // Paginación R-10 visible con el total del backend.
        expect(find.text('Mostrando 3 de 3'), findsOneWidget);
      },
    );

    testWidgets(
      'el filtro «Vencido» consulta solo los vencidos (FR-012)',
      (WidgetTester tester) async {
        final _MaintenanceServiceFake fake = _MaintenanceServiceFake();

        await pumpScreen(tester, fake: fake);

        await tester.tap(find.text('Vencido'));
        await tester.pumpAndSettle();

        expect(
          fake.estadosConsultados,
          <String>['', 'VENCIDO'],
          reason: 'la primera carga es sin filtro y la segunda con VENCIDO',
        );
        expect(
          find.textContaining('No hay mantenimientos con este filtro'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'la búsqueda del header se envía como filtro de tipo o placas',
      (WidgetTester tester) async {
        final _MaintenanceServiceFake fake = _MaintenanceServiceFake();
        final ShellProvider shell = ShellProvider(initialWidth: 1440);

        await pumpScreen(tester, fake: fake, shell: shell);

        shell.setQuery(SearchHints.maintenance, 'aceite');
        await tester.pump();
        await tester.pump();

        expect(
          fake.busquedasConsultadas,
          <String>['', 'aceite'],
          reason: 'el texto del header debe viajar al filtro buscar (HU4)',
        );
      },
    );

    testWidgets(
      'recepción consulta la lista pero no ve controles de escritura (V3)',
      (WidgetTester tester) async {
        final _MaintenanceServiceFake fake = _MaintenanceServiceFake(
          page: _paginaConLosTresEstados,
        );

        await pumpScreen(tester, fake: fake, rol: Rol.receptionist);

        expect(find.text('Cambio de aceite'), findsOneWidget);
        expect(find.text('Programar'), findsNothing);
        expect(find.byTooltip('Editar mantenimiento'), findsNothing);
      },
    );

    testWidgets(
      'con sesión de administrador sí se ofrecen «Programar» y «Editar»',
      (WidgetTester tester) async {
        final _MaintenanceServiceFake fake = _MaintenanceServiceFake(
          page: _paginaConLosTresEstados,
        );

        await pumpScreen(tester, fake: fake, rol: Rol.admin);

        expect(find.text('Programar'), findsOneWidget);
        expect(find.byTooltip('Editar mantenimiento'), findsNWidgets(3));
      },
    );

    testWidgets(
      'el error del backend se muestra con opción de reintentar',
      (WidgetTester tester) async {
        final _MaintenanceServiceFake fake = _MaintenanceServiceFake(
          failure: ApiException(
            'El servicio de mantenimientos no respondió',
            codigo: 'TIMEOUT',
            statusCode: 503,
          ),
        );

        await pumpScreen(tester, fake: fake);

        expect(
          find.text('El servicio de mantenimientos no respondió'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
      },
    );
  });
}
