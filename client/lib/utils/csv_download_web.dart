// Implementación web de la exportación CSV (FR-037): crea un enlace temporal
// con el contenido (UTF-8 con BOM, para que la hoja de cálculo lea acentos y
// eñes) y lo activa para que el navegador descargue el archivo. Solo se
// compila cuando `dart.library.html` está disponible (la app web).
import 'dart:js_interop';

import 'package:flutter/material.dart';

@JS('document.createElement')
external _Enlace _crearElemento(String etiqueta);

extension type _Enlace._(JSObject _) implements JSObject {
  external set href(String valor);
  external set download(String valor);
  external void click();
}

Future<void> descargarCsv(
  BuildContext context, {
  required String nombre,
  required String contenido,
}) async {
  final String conBom = contenido.startsWith('\uFEFF') ? contenido : '\uFEFF$contenido';
  final _Enlace enlace = _crearElemento('a');
  enlace.href = 'data:text/csv;charset=utf-8,${Uri.encodeComponent(conBom)}';
  enlace.download = nombre;
  enlace.click();
}
