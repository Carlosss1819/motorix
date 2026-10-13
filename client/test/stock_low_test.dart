// Pruebas de las alertas de stock bajo en el inventario (US8, Sprint 3): el
// chip «Stock bajo» de las refacciones que llegaron a su mínimo, el filtro
// de alertas que pide `stockBajo=true` al backend y el caso `stock_minimo =
// 0` que nunca se marca (FR-020, FR-021, R-10, SC-008, V4).
// Fuente de verdad: specs/003-historial-inventario/contracts/parts.md.
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
import 'package:motorix_client/screens/parts_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/services/parts_service.dart';
import 'package:motorix_client/utils/app_theme.dart';

/// Servicio falso que se comporta como el backend: con `stockBajo` devuelve
/// solo las refacciones en alerta y registra cada filtro recibido.
class _PartsServiceFake extends PartsService {
  _PartsServiceFake({required this.enAlerta, required this.sinAlerta})
      : super(ApiClient());

  /// Refacciones cuyo stock ya llegó al mínimo.
  final List<Part> enAlerta;

  /// Refacciones con holgura (incluye las de mínimo 0).
  final List<Part> sinAlerta;

  /// Filtros `stockBajo` que recibió la llamada, en orden.
  final List<bool> filtrosStockBajo = <bool>[];

  @override
  Future<PartPage> list({
    String buscar = '',
    bool stockBajo = false,
    bool? activa,
    int pagina = 1,
    int porPagina = 10,
  }) async {
    filtrosStockBajo.add(stockBajo);
    final List<Part> elementos = stockBajo
        ? enAlerta
        : <Part>[...enAlerta, ...sinAlerta];
    return PartPage(
      elementos: elementos,
      pagina: 1,
      paginas: 1,
      total: elementos.length,
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

/// Refacción en alerta: 3 unidades con mínimo 5 (FR-021).
const Part _enAlerta = Part(
  id: 1,
  codigo: 'PAD-001',
  nombre: 'Juego de pastillas delanteras',
  categoria: 'Frenos',
  marca: null,
  stockActual: 3,
  stockMinimo: 5,
  stockBajo: true,
  precioCompra: null,
  precioVenta: null,
  activa: true,
);

/// Refacción con holgura: 8 unidades con mínimo 2.
const Part _sinAlerta = Part(
  id: 2,
  codigo: 'FIL-001',
  nombre: 'Filtro de aceite',
  categoria: 'Motor',
  marca: null,
  stockActual: 8,
  stockMinimo: 2,
  stockBajo: false,
  precioCompra: null,
  precioVenta: null,
  activa: true,
);

/// Refacción sin mínimo: 0 unidades con stock mínimo 0 (V4, FR-021).
const Part _minimoCero = Part(
  id: 3,
  codigo: 'LLA-001',
  nombre: 'Llantas de repuesto',
  categoria: 'Transmisión',
  marca: null,
  stockActual: 0,
  stockMinimo: 0,
  stockBajo: false,
  precioCompra: null,
  precioVenta: null,
  activa: true,
);

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<PartsProvider> pumpScreen(
    WidgetTester tester, {
    required _PartsServiceFake fake,
    String rol = Rol.admin,
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final PartsProvider provider = PartsProvider(
      api: ApiClient(),
      service: fake,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ShellProvider>(
            create: (_) => ShellProvider(initialWidth: 1440),
          ),
          ChangeNotifierProvider<AuthProvider>.value(
            value: _AuthFake(rol),
          ),
          ChangeNotifierProvider<PartsProvider>.value(value: provider),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PartsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return provider;
  }

  group('PartsScreen — alertas de stock bajo (US8)', () {
    testWidgets(
      'marca con «Stock bajo» solo a la refacción que llegó a su mínimo (SC-008)',
      (WidgetTester tester) async {
        await pumpScreen(
          tester,
          fake: _PartsServiceFake(
            enAlerta: const <Part>[_enAlerta],
            sinAlerta: const <Part>[_sinAlerta],
          ),
        );

        expect(find.text('Juego de pastillas delanteras'), findsOneWidget);
        expect(find.text('Filtro de aceite'), findsOneWidget);
        expect(
          find.text('Stock bajo'),
          findsOneWidget,
          reason: 'solo la refacción en alerta lleva el chip',
        );
        // El stock en alerta se muestra en rojo junto a su mínimo.
        expect(find.text('Stock: 3 · mín. 5'), findsOneWidget);
      },
    );

    testWidgets(
      'el filtro de alertas pide stockBajo=true al backend y anuncia el total',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake(
          enAlerta: const <Part>[_enAlerta],
          sinAlerta: const <Part>[_sinAlerta],
        );
        final PartsProvider provider = await pumpScreen(tester, fake: fake);

        expect(fake.filtrosStockBajo, <bool>[false]);

        await tester.tap(find.byKey(const Key('filtro-stock-bajo')));
        await tester.pumpAndSettle();

        expect(fake.filtrosStockBajo.last, isTrue);
        expect(provider.soloStockBajo, isTrue);
        expect(
          find.text('Inventario · 1 refacciones con stock bajo'),
          findsOneWidget,
        );
        // El listado filtrado trae solo la refacción en alerta.
        expect(find.text('Juego de pastillas delanteras'), findsOneWidget);
        expect(find.text('Filtro de aceite'), findsNothing);
        expect(find.text('Stock bajo'), findsOneWidget);

        // Al desactivarlo vuelve al catálogo completo.
        await tester.tap(find.byKey(const Key('filtro-stock-bajo')));
        await tester.pumpAndSettle();

        expect(fake.filtrosStockBajo.last, isFalse);
        expect(provider.soloStockBajo, isFalse);
        expect(find.text('Inventario · 2 refacciones'), findsOneWidget);
        expect(find.text('Filtro de aceite'), findsOneWidget);
      },
    );

    testWidgets(
      'un stock mínimo de 0 nunca se marca ni entra en las alertas (V4)',
      (WidgetTester tester) async {
        final _PartsServiceFake fake = _PartsServiceFake(
          enAlerta: const <Part>[],
          sinAlerta: const <Part>[_minimoCero],
        );
        final PartsProvider provider = await pumpScreen(tester, fake: fake);

        expect(find.text('Llantas de repuesto'), findsOneWidget);
        expect(find.text('Stock: 0 · mín. 0'), findsOneWidget);
        expect(find.text('Stock bajo'), findsNothing);

        await tester.tap(find.byKey(const Key('filtro-stock-bajo')));
        await tester.pumpAndSettle();

        expect(provider.soloStockBajo, isTrue);
        expect(
          find.textContaining('No hay refacciones con stock bajo'),
          findsOneWidget,
          reason: 'un mínimo de 0 nunca genera alerta que mostrar',
        );
      },
    );

    testWidgets(
      'recepción también ve el semáforo y el filtro, en modo consulta',
      (WidgetTester tester) async {
        await pumpScreen(
          tester,
          rol: Rol.receptionist,
          fake: _PartsServiceFake(
            enAlerta: const <Part>[_enAlerta],
            sinAlerta: const <Part>[],
          ),
        );

        expect(find.text('Stock bajo'), findsOneWidget);
        expect(find.byKey(const Key('filtro-stock-bajo')), findsOneWidget);
        expect(find.text('Nueva refacción'), findsNothing);
      },
    );
  });
}
