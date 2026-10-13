/// Número aceptando tanto el valor numérico como el texto que MySQL devuelve
/// para las columnas DECIMAL (por ejemplo, `"450.00"`).
num asNum(Object? value, [num fallback = 0]) {
  if (value is num) {
    return value;
  }
  return num.tryParse(value?.toString() ?? '') ?? fallback;
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String asString(Object? value) => value?.toString() ?? '';

/// Entero que distingue `null` (sin valor) de un número, para los campos
/// opcionales como el mecánico asignado o la cita de origen.
int? asIntOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final String text = value.toString();
  if (text.isEmpty) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(text);
}

String? asStringOrNull(Object? value) {
  final String text = value?.toString() ?? '';
  return text.isEmpty ? null : text;
}

bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) {
    return value;
  }
  return fallback;
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((Object? key, Object? val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asList(Object? value) {
  if (value is List) {
    return value.whereType<Map<dynamic, dynamic>>().map(Map<String, dynamic>.from).toList();
  }
  return <Map<String, dynamic>>[];
}
