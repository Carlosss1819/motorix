import 'package:flutter/material.dart';

import 'print_service_stub.dart'
    if (dart.library.html) 'print_service_web.dart' as impl;

/// Delegación de la impresión del comprobante (FR-008, CA-5, D3): en la web
/// abre el diálogo de impresión del navegador sobre la página visible; en la
/// aplicación de escritorio (sin navegador) ofrece copiar el texto del
/// comprobante. No se genera ni se archiva ningún PDF.
Future<void> imprimirComprobante(BuildContext context, {String texto = ''}) =>
    impl.abrirDialogoImpresion(context, texto: texto);
