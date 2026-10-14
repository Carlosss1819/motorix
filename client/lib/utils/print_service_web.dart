// Implementación web de la impresión (FR-008, D3): `window.print()` abre el
// diálogo de impresión del navegador para la página visible, sin PDF
// almacenado. Este archivo solo se compila cuando `dart.library.html` está
// disponible (la app web); en escritorio se usa print_service_stub.dart.
import 'dart:js_interop';

import 'package:flutter/material.dart';

/// Abre el diálogo de impresión del navegador (el `context` no hace falta:
/// se imprime la página que el navegador está mostrando).
Future<void> abrirDialogoImpresion(
  BuildContext context, {
  String texto = '',
}) async {
  _imprimirNavegador();
}

@JS('window.print')
external void _imprimirNavegador();
