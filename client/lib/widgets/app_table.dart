import 'package:flutter/material.dart';

/// Crea una columna fluida para las tablas de listado.
///
/// La columna recibe su proporción del ancho disponible según [weight] y
/// nunca baja de [minWidth] ni del ancho intrínseco de su contenido, de modo
/// que se distribuye de forma responsiva sin cortar el texto.
DataColumn fluidColumn(
  String label, {
  double weight = 1.0,
  double minWidth = 110.0,
}) {
  return DataColumn(
    label: Text(label),
    columnWidth: MaxColumnWidth(
      FlexColumnWidth(weight),
      MaxColumnWidth(
        FixedColumnWidth(minWidth),
        const IntrinsicColumnWidth(),
      ),
    ),
  );
}

/// Tabla de listado que ocupa el 100% del ancho disponible.
///
/// Impone el ancho del área disponible como ancho mínimo de la tabla para que
/// las columnas con flex llenen el espacio en lugar de quedarse en su ancho
/// intrínseco. En pantallas angostas, donde el contenido no cabe, la tabla se
/// desplaza en horizontal.
class FullWidthTable extends StatelessWidget {
  const FullWidthTable({super.key, required this.columns, required this.rows});

  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: availableWidth),
            child: DataTable(columns: columns, rows: rows),
          ),
        );
      },
    );
  }
}
