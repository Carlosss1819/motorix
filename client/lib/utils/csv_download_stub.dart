// Implementación de escritorio de la exportación CSV (FR-037): sin navegador
// no hay descarga, así que se ofrece copiar el contenido para pegarlo en una
// hoja de cálculo o guardarlo como archivo .csv.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/confirm_dialog.dart';

Future<void> descargarCsv(
  BuildContext context, {
  required String nombre,
  required String contenido,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext contexto) => AlertDialog(
      title: const Text('Exportar CSV'),
      content: Text(
        'Esta versión de escritorio no descarga archivos: copia el contenido '
        'y guárdalo como «$nombre» o pégalo en tu hoja de cálculo.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(contexto),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          key: const Key('boton-copiar-csv'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: contenido));
            if (contexto.mounted) {
              Navigator.pop(contexto);
            }
          },
          child: const Text('Copiar contenido'),
        ),
      ],
    ),
  );
}
