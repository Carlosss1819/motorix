/// Formateadores de presentación. Evitan escribir valores de formato en las
/// pantallas.
abstract final class Formatters {
  /// Fecha ISO `YYYY-MM-DD` → `DD/MM/YYYY`.
  static String date(String? iso) {
    if (iso == null || iso.isEmpty) {
      return 'Sin registro';
    }
    final List<String> parts = iso.split('-');
    if (parts.length != 3) {
      return iso;
    }
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  /// Fecha y hora `YYYY-MM-DD HH:mm:ss` → `DD/MM/YYYY HH:mm`.
  static String dateTime(String? value) {
    if (value == null || value.isEmpty) {
      return 'Sin registro';
    }
    final List<String> parts = value.split(' ');
    final String fecha = date(parts.first);
    if (parts.length < 2) {
      return fecha;
    }
    final List<String> hora = parts[1].split(':');
    if (hora.length < 2) {
      return '$fecha ${parts[1]}';
    }
    return '$fecha ${hora[0]}:${hora[1]}';
  }

  /// Número con separador de miles (45000 → `45,000`).
  static String number(int value) {
    final bool negative = value < 0;
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return negative ? '-$buffer' : buffer.toString();
  }

  /// Kilometraje con separador de miles y unidad (45000 → `45,000 km`).
  static String mileage(int value) => '${number(value)} km';

  /// Dinero en pesos con separador de miles y dos decimales (450 → `$450.00`).
  ///
  /// Acepta `num` porque el backend entrega los DECIMAL como texto.
  static String money(num value) {
    final List<String> parts = value.toStringAsFixed(2).split('.');
    return '\$${number(int.parse(parts[0]))}.${parts[1]}';
  }
}
