// Implementación de escritorio de la impresión (FR-008, D3): la aplicación
// de Windows no tiene diálogo de impresión del navegador, así que ofrece
// copiar el texto del comprobante para pegarlo e imprimirlo donde se
// prefiera. Tampoco genera archivos PDF.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/confirm_dialog.dart';

/// Diálogo «Imprimir comprobante» con la opción de copiar su texto plano.
Future<void> abrirDialogoImpresion(
  BuildContext context, {
  String texto = '',
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext contexto) => AlertDialog(
      title: const Text('Imprimir comprobante'),
      content: const Text(
        'Esta versión de escritorio no abre el diálogo de impresión del '
        'navegador: copia el texto del comprobante y pégalo en tu programa '
        'de impresión.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(contexto),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          key: const Key('boton-copiar-comprobante'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: texto));
            if (contexto.mounted) {
              Navigator.pop(contexto);
            }
          },
          child: const Text('Copiar texto'),
        ),
      ],
    ),
  );
}
