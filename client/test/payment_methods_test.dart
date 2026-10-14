// Pruebas del selector de método de pago (US2, Sprint 4): los cuatro métodos
// se ofrecen con su etiqueta legible (FR-002), cada uno se registra con su
// valor enum y sin método no se envía y aparece la validación en español
// (HU2-3). Fuente de verdad: specs/004-pagos-tickets-dashboard/contracts/payments.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:motorix_client/models/order_total.dart';
import 'package:motorix_client/models/payment.dart';
import 'package:motorix_client/providers/payment_provider.dart';
import 'package:motorix_client/screens/payment_form_screen.dart';
import 'package:motorix_client/services/api_client.dart';
import 'package:motorix_client/utils/app_theme.dart';

import 'fake_payments_service.dart';

/// Total de ejemplo no nulo: el formulario precarga el monto con él y así la
/// validación local del monto siempre pasa (FR-015).
const OrderTotal _totalPrueba = OrderTotal(
  ordenId: 7,
  subtotalManoDeObra: 450,
  subtotalRefacciones: 0,
  total: 450,
);

void main() {
  setUpAll(() {
    // En pruebas no se descargan fuentes desde internet.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Formulario de pago sobre una pantalla vacía, como en la app real: al
  /// guardar, el pop descubre la pantalla inferior.
  ///
  /// [semilla] cambia la clave de la raíz: sin ella, un segundo
  /// `pumpWidget` reutiliza el árbol (navigator y provider incluidos) y no
  /// vuelve a montar el formulario con su servicio falso nuevo.
  Future<FakePaymentsService> pumpForm(
    WidgetTester tester, {
    String semilla = 'form',
  }) async {
    tester.view.physicalSize = const Size(1280, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final FakePaymentsService fake = FakePaymentsService(total: _totalPrueba);

    await tester.pumpWidget(
      MultiProvider(
        key: ValueKey<String>(semilla),
        providers: [
          ChangeNotifierProvider<PaymentsProvider>(
            create: (_) => PaymentsProvider(api: ApiClient(), service: fake),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SizedBox.shrink()),
          routes: <String, WidgetBuilder>{
            '/pago': (_) => const Scaffold(
                  body: PaymentFormScreen(
                    args: PaymentFormArgs(ordenId: 7),
                  ),
                ),
          },
          initialRoute: '/pago',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return fake;
  }

  group('PaymentFormScreen — métodos de pago (US2, FR-002)', () {
    testWidgets(
      'el selector ofrece los cuatro métodos con su etiqueta legible',
      (WidgetTester tester) async {
        await pumpForm(tester);

        await tester.tap(find.byKey(const Key('selector-metodo')));
        await tester.pumpAndSettle();

        expect(find.text('Efectivo'), findsWidgets);
        expect(find.text('Tarjeta'), findsOneWidget);
        expect(find.text('Transferencia'), findsOneWidget);
        expect(find.text('Mercado Pago'), findsOneWidget);
      },
    );

    testWidgets(
      'cada método se registra con su valor enum y se muestra la etiqueta',
      (WidgetTester tester) async {
        for (final String valor in paymentMethodValues) {
          final FakePaymentsService fake =
              await pumpForm(tester, semilla: valor);
          final String etiqueta = paymentMethodLabel(valor);

          await tester.tap(find.byKey(const Key('selector-metodo')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(etiqueta).last);
          await tester.pumpAndSettle();

          // La etiqueta legible es la que queda visible en el campo (HU2-3).
          expect(
            find.descendant(
              of: find.byKey(const Key('selector-metodo')),
              matching: find.text(etiqueta),
            ),
            findsOneWidget,
          );

          await tester.tap(find.widgetWithText(FilledButton, 'Registrar pago'));
          await tester.pumpAndSettle();

          expect(fake.ultimoRegistrado, isNotNull);
          expect(
            fake.ultimoRegistrado!.metodo,
            valor,
            reason: 'el valor guardado debe ser el enum del contrato',
          );
          expect(find.byType(PaymentFormScreen), findsNothing);

          // Deja pasar la duración del snackbar para no encolar avisos.
          await tester.pump(const Duration(seconds: 4));
        }
      },
    );

    testWidgets(
      'sin método no se envía y muestra la validación en español (HU2-3)',
      (WidgetTester tester) async {
        final FakePaymentsService fake = await pumpForm(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Registrar pago'));
        await tester.pumpAndSettle();

        expect(find.text('El método de pago es obligatorio.'), findsOneWidget);
        expect(fake.ultimoRegistrado, isNull, reason: 'no debe enviarse nada');
        expect(
          find.byType(PaymentFormScreen),
          findsOneWidget,
          reason: 'el formulario permanece abierto para corregir',
        );
      },
    );
  });
}
