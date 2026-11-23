/// Convierte valores provenientes de Firestore o de formularios a `double`.
double asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return parseDecimal(value, fallback: fallback);
  return fallback;
}

/// Convierte valores provenientes de Firestore a `int`.
int asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Acepta entradas como `1,234.56`, `1234,56` o `$ 1 234.56`.
double parseDecimal(String raw, {double fallback = 0}) {
  var value = raw.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (value.isEmpty) return fallback;

  final lastComma = value.lastIndexOf(',');
  final lastDot = value.lastIndexOf('.');

  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      // Formato europeo: 1.234,56
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // Formato anglosajón: 1,234.56
      value = value.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    // Sin punto: se interpreta la coma como separador decimal.
    value = value.replaceAll(',', '.');
  }

  return double.tryParse(value) ?? fallback;
}

/// Redondea a dos decimales para evitar errores visibles de punto flotante.
double roundMoney(double value) {
  if (!value.isFinite) return 0;
  return (value * 100).roundToDouble() / 100;
}
