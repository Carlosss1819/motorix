import 'package:flutter/material.dart';

import 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web.dart' as impl;

/// Exportación CSV de los reportes (Sprint 7, Entrega B, FR-037): en la web
/// descarga el archivo con el nombre que indica el backend; en la aplicación
/// de escritorio ofrece copiar el contenido. Sin librerías nuevas.
Future<void> descargarCsv(
  BuildContext context, {
  required String nombre,
  required String contenido,
}) =>
    impl.descargarCsv(context, nombre: nombre, contenido: contenido);
