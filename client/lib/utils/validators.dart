/// Validaciones compartidas de los formularios.
///
/// Todos los mensajes están en español y explican qué dato corregir.
abstract final class Validators {
  /// Texto obligatorio no vacío.
  static String? required(String? value, String campo) {
    if (value == null || value.trim().isEmpty) {
      return 'El campo $campo es obligatorio.';
    }
    return null;
  }

  /// Correo electrónico: opcional, pero si se escribe debe tener formato válido.
  static String? email(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final RegExp pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(trimmed)) {
      return 'Escribe un correo electrónico válido.';
    }
    return null;
  }

  /// Política de contraseña (FR-008 / RN-17): mínimo 8 caracteres con
  /// mayúscula, minúscula y número.
  static String? password(String? value) {
    final String text = value ?? '';
    if (text.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    if (!text.contains(RegExp(r'[A-ZÁÉÍÓÚÑ]'))) {
      return 'La contraseña debe incluir al menos una letra mayúscula.';
    }
    if (!text.contains(RegExp(r'[a-záéíóúñ]'))) {
      return 'La contraseña debe incluir al menos una letra minúscula.';
    }
    if (!text.contains(RegExp(r'[0-9]'))) {
      return 'La contraseña debe incluir al menos un número.';
    }
    return null;
  }

  /// Requisitos de la política de contraseña, para mostrar la lista viva.
  static Map<String, bool> passwordRequirements(String value) {
    return <String, bool>{
      'Mínimo 8 caracteres': value.length >= 8,
      'Al menos una mayúscula': value.contains(RegExp(r'[A-ZÁÉÍÓÚÑ]')),
      'Al menos una minúscula': value.contains(RegExp(r'[a-záéíóúñ]')),
      'Al menos un número': value.contains(RegExp(r'[0-9]')),
    };
  }

  /// Año del vehículo: número entero de cuatro dígitos dentro de un rango razonable.
  static String? year(String? value) {
    final String? empty = required(value, 'el año');
    if (empty != null) {
      return 'Escribe el año del vehículo.';
    }
    final int? parsed = int.tryParse(value!.trim());
    final int maxYear = DateTime.now().year + 1;
    if (parsed == null || parsed < 1900 || parsed > maxYear) {
      return 'Escribe un año entre 1900 y $maxYear.';
    }
    return null;
  }

  /// Kilometraje actual: entero mayor o igual que cero (FR-016).
  static String? mileage(String? value) {
    final String? empty = required(value, 'el kilometraje');
    if (empty != null) {
      return 'Escribe el kilometraje actual.';
    }
    final int? parsed = int.tryParse(value!.trim());
    if (parsed == null || parsed < 0) {
      return 'El kilometraje debe ser un número igual o mayor a 0.';
    }
    return null;
  }

  /// Entero mayor o igual que cero u opcional: el vacío se acepta y no se
  /// envía al backend (campos como los intervalos o la fecha objetivo).
  static String? optionalNonNegativeInt(String? value, String campo) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) {
      return 'El campo $campo debe ser un número igual o mayor a 0.';
    }
    return null;
  }

  /// Entero positivo u opcional: el vacío se acepta (intervalos y
  /// antelaciones, que el backend exige mayores que cero).
  static String? optionalPositiveInt(String? value, String campo) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return 'El campo $campo debe ser un número entero mayor a 0.';
    }
    return null;
  }

  /// Fecha opcional con formato `AAAA-MM-DD`; el vacío se acepta.
  static String? optionalFecha(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(text);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != text) {
      return 'Escribe una fecha con el formato AAAA-MM-DD.';
    }
    return null;
  }
}
