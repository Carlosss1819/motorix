import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/part.dart';
import 'package:motorix_client/providers/parts_provider.dart';
import 'package:motorix_client/screens/part_form_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_parts_service.dart';

/// Pruebas del formulario de refacción con los precios del Sprint 5 (US1):
/// dos decimales y tope (FR-003) y aviso D-07 cuando el precio de venta es
/// menor que el de compra (FR-004).
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<FakePartsService> abrirFormulario(
    WidgetTester tester, {
    List<String> advertencias = const <String>[],
  }) async {
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final FakePartsService fake = FakePartsService()
      ..advertenciasAlGuardar = advertencias;

    await tester.pumpWidget(
      ChangeNotifierProvider<PartsProvider>(
        create: (_) => PartsProvider(api: ApiClient(), service: fake),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => const Scaffold(
                      body: PartFormScreen(args: PartFormArgs()),
                    ),
                  ),
                ),
                child: const Text('Abrir formulario'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
    return fake;
  }

  Future<void> capturar(
    WidgetTester tester, {
    String compra = '',
    String venta = '',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Código *'),
      'PAS-001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre *'),
      'Pastillas delanteras',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Categoría *'),
      'Frenos',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio de compra'),
      compra,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio de venta'),
      venta,
    );
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
  }

  testWidgets('rechaza_un_precio_con_tres_decimales', (WidgetTester tester) async {
    final FakePartsService fake = await abrirFormulario(tester);
    await capturar(tester, venta: '320.555');

    expect(
      find.text('El campo el precio de venta debe tener máximo 2 decimales.'),
      findsOneWidget,
    );
    expect(fake.guardados, isEmpty);
  });

  testWidgets('rechaza_un_precio_mayor_al_tope', (WidgetTester tester) async {
    final FakePartsService fake = await abrirFormulario(tester);
    await capturar(tester, compra: '1000000');

    expect(
      find.text('El campo el precio de compra no puede ser mayor a 999,999.99.'),
      findsOneWidget,
    );
    expect(fake.guardados, isEmpty);
  });

  testWidgets('acepta_999999_99_con_dos_decimales', (WidgetTester tester) async {
    final FakePartsService fake = await abrirFormulario(tester);
    await capturar(tester, compra: '999999.99', venta: '999999.99');

    expect(fake.guardados, hasLength(1));
    expect(fake.guardados.first.precioVenta, 999999.99);
    expect(find.text('Refacción registrada en el inventario.'), findsOneWidget);
  });

  testWidgets(
    'muestra_el_aviso_warning_cuando_la_venta_es_menor_que_la_compra',
    (WidgetTester tester) async {
      final FakePartsService fake = await abrirFormulario(
        tester,
        advertencias: const <String>[Part.precioVentaMenorACompra],
      );
      await capturar(tester, compra: '200', venta: '150');

      expect(fake.guardados, hasLength(1), reason: 'el guardado no se bloquea');
      expect(find.text(kAvisoVentaMenorACompra), findsOneWidget);
      final SnackBar snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, AppTheme.light().extension<MotorixColors>()!.warning);
    },
  );
}
