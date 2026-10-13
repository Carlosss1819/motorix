import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/app_user.dart';
import 'package:motorix_client/models/enums.dart';
import 'package:motorix_client/models/part.dart';
import 'package:motorix_client/providers/auth_provider.dart';
import 'package:motorix_client/providers/parts_provider.dart';
import 'package:motorix_client/providers/shell_provider.dart';
import 'package:motorix_client/screens/part_form_screen.dart';
import 'package:motorix_client/screens/parts_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/parts_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

/// Servicio falso con datos en memoria: no se abre ninguna conexión y se
/// registran las altas y las desactivaciones para los asserts.
class _PartsServiceFake extends PartsService {
  _PartsServiceFake({this.page, this.creacionFalla}) : super(ApiClient());

  /// Página que devuelve `list`.
  PartPage? page;

  /// Si se define, `create` lanza este error (por ejemplo el 409 duplicado).
  ApiException? creacionFalla;

  final List<Map<String, Object?>> altas = <Map<String, Object?>>[];
  final List<int> desactivadas = <int>[];

  @override
  Future<PartPage> list({
    String buscar = '',
    bool stockBajo = false,
    bool? activa,
    int pagina = 1,
    int porPagina = 10,
  }) async {
    return page ??
        const PartPage(
          elementos: <Part>[],
          pagina: 1,
          paginas: 1,
          total: 0,
        );
  }

  @override
  Future<Part> create({
    required String codigo,
    required String nombre,
    required String categoria,
    String? marca,
    int stockInicial = 0,
    int stockMinimo = 0,
    num? precioCompra,
    num? precioVenta,
  }) async {
    if (creacionFalla != null) {
      throw creacionFalla!;
    }
    altas.add(<String, Object?>{
      'codigo': codigo,
      'nombre': nombre,
      'categoria': categoria,
      'marca': marca,
      'stockInicial': stockInicial,
      'stockMinimo': stockMinimo,
      'precioCompra': precioCompra,
      'precioVenta': precioVenta,
    });
    return Part.fromJson(<String, dynamic>{
      'id': 100 + altas.length,
      'codigo': codigo,
      'nombre': nombre,
      'categoria': categoria,
      'marca': marca,
      'stockActual': stockInicial,
      'stockMinimo': stockMinimo,
      'stockBajo': false,
      'precioCompra': precioCompra,
      'precioVenta': precioVenta,
      'activa': true,
    });
  }

  @override
  Future<String> deactivate(int id) async {
    desactivadas.add(id);
    return 'Refacción desactivada.';
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

/// Refacción de ejemplo (SC-005): con marca, precios y stock bajo.
const Part _refaccion = Part(
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
);

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required _PartsServiceFake fake,
    String rol = Rol.admin,
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ShellProvider>(
            create: (_) => ShellProvider(initialWidth: 1440),
          ),
          ChangeNotifierProvider<AuthProvider>.value(
            value: _AuthFake(rol),
          ),
          ChangeNotifierProvider<PartsProvider>(
            create: (_) => PartsProvider(api: ApiClient(), service: fake),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PartsScreen()),
          // La ruta se declara como `Route<bool?>` para casar con el
          // `pushNamed<bool>` de la pantalla (el formulario pop(true)).
          onGenerateRoute: (RouteSettings settings) {
            if (settings.name == '/parts/new') {
              return MaterialPageRoute<bool>(
                builder: (_) => Scaffold(
                  body: PartFormScreen(args: const PartFormArgs()),
                ),
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

  Future<void> abrirFormulario(WidgetTester tester) async {
    await tester.tap(find.text('Nueva refacción'));
    await tester.pumpAndSettle();
  }

  group('PartsScreen — catálogo de refacciones (US5/HU5)', () {
    testWidgets(
      'muestra código, nombre, categoría, marca, stock y precios (SC-005)',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake(
          page: const PartPage(
            elementos: <Part>[_refaccion],
            pagina: 1,
            paginas: 1,
            total: 1,
          ),
        );
        await pumpScreen(tester, fake: fake);

        expect(find.text('Juego de pastillas delanteras'), findsOneWidget);
        expect(find.text('PAD-001'), findsOneWidget);
        expect(find.text('Frenos · Brembo'), findsOneWidget);
        expect(
          find.text('Stock: 3 · mín. 5'),
          findsOneWidget,
          reason: 'el stock actual y el mínimo deben leerse de un vistazo',
        );
        expect(find.text('Compra: \$180.00'), findsOneWidget);
        expect(find.text('Venta: \$320.00'), findsOneWidget);
      },
    );

    testWidgets(
      'un inventario vacío muestra el estado vacío en español',
      (WidgetTester tester) async {
        await pumpScreen(tester, fake: _PartsServiceFake());

        expect(
          find.textContaining('El inventario está vacío'),
          findsOneWidget,
        );
        expect(find.text('Nueva refacción'), findsOneWidget);
      },
    );

    testWidgets(
      'el formulario de alta registra la refacción con su stock inicial',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake();
        await pumpScreen(tester, fake: fake);

        await abrirFormulario(tester);

        // Código, nombre y categoría; stock inicial y mínimo.
        await tester.enterText(find.byType(TextField).at(0), 'ACE-5W30');
        await tester.enterText(find.byType(TextField).at(1), 'Aceite 5W30');
        await tester.enterText(find.byType(TextField).at(2), 'Lubricantes');
        await tester.enterText(find.byType(TextField).at(4), '12');
        await tester.enterText(find.byType(TextField).at(5), '4');

        await tester.tap(find.text('Registrar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(fake.altas, hasLength(1));
        expect(fake.altas.single['codigo'], 'ACE-5W30');
        expect(fake.altas.single['nombre'], 'Aceite 5W30');
        expect(fake.altas.single['categoria'], 'Lubricantes');
        expect(fake.altas.single['stockInicial'], 12);
        expect(fake.altas.single['stockMinimo'], 4);
        expect(
          find.text('Refacción registrada en el inventario.'),
          findsOneWidget,
        );
        // Deja pasar la duración del snackbar para no encolar avisos.
        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'un código duplicado responde 409 y se explica en el aviso (FR-017)',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake(
          creacionFalla: ApiException(
            'Ya existe una refacción con este código',
            codigo: 'CODIGO_DUPLICADO',
            statusCode: 409,
          ),
        );
        await pumpScreen(tester, fake: fake);

        await abrirFormulario(tester);

        await tester.enterText(find.byType(TextField).at(0), 'PAD-001');
        await tester.enterText(
          find.byType(TextField).at(1),
          'Otra pastilla',
        );
        await tester.enterText(find.byType(TextField).at(2), 'Frenos');

        await tester.tap(find.text('Registrar'));
        await tester.pump();

        expect(
          find.text('Ya existe una refacción con este código'),
          findsOneWidget,
        );
        expect(fake.altas, isEmpty, reason: 'no debe registrarse nada');
      },
    );

    testWidgets(
      'la desactivación exige confirmación y solo entonces se envía (FR-019)',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake(
          page: const PartPage(
            elementos: <Part>[_refaccion],
            pagina: 1,
            paginas: 1,
            total: 1,
          ),
        );
        await pumpScreen(tester, fake: fake);

        await tester.tap(find.byTooltip('Desactivar refacción'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('¿Continuar?'),
          findsOneWidget,
          reason: 'la confirmación debe explicar que el historial persiste',
        );

        // Cancelar no desactiva nada.
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Cancelar'),
          ),
        );
        await tester.pumpAndSettle();
        expect(fake.desactivadas, isEmpty);

        // Confirmar sí envía la desactivación.
        await tester.tap(find.byTooltip('Desactivar refacción'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Desactivar'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(fake.desactivadas, <int>[1]);
        expect(find.text('Refacción desactivada.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      },
    );

    testWidgets(
      'una refacción desactivada no ofrece acciones de escritura',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake(
          page: const PartPage(
            elementos: <Part>[
              Part(
                id: 2,
                codigo: 'BUJ-IR01',
                nombre: 'Juego de bujías iridium',
                categoria: 'Encendido',
                marca: null,
                stockActual: 8,
                stockMinimo: 2,
                stockBajo: false,
                precioCompra: null,
                precioVenta: null,
                activa: false,
              ),
            ],
            pagina: 1,
            paginas: 1,
            total: 1,
          ),
        );
        await pumpScreen(tester, fake: fake);

        expect(find.text('Juego de bujías iridium'), findsOneWidget);
        expect(find.text('Encendido'), findsOneWidget);
        expect(find.text('Desactivada'), findsOneWidget);
        expect(find.byTooltip('Editar refacción'), findsNothing);
        expect(find.byTooltip('Desactivar refacción'), findsNothing);
      },
    );
  });
}
