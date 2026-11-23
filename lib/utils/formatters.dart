import 'package:intl/intl.dart';

import '../core/app_config.dart';
import '../core/moneda.dart';

/// Formatos compartidos por la interfaz, el historial y el PDF.
abstract final class AppFormatters {
  static final Map<String, NumberFormat> _currencyFormats =
      <String, NumberFormat>{};

  static NumberFormat _currencyFormat(Moneda moneda) {
    return _currencyFormats.putIfAbsent(
      moneda.codigo,
      () => NumberFormat.currency(
        locale: AppConfig.locale,
        symbol: moneda.simbolo,
        decimalDigits: moneda.decimales,
      ),
    );
  }

  static final NumberFormat _decimal = NumberFormat(
    '#,##0.##',
    AppConfig.locale,
  );
  static final DateFormat _date = DateFormat(
    "d 'de' MMMM 'de' y",
    AppConfig.locale,
  );
  static final DateFormat _dateTime = DateFormat(
    'dd/MM/yyyy HH:mm',
    AppConfig.locale,
  );
  static final DateFormat _shortDate = DateFormat('dd MMM y', AppConfig.locale);

  /// Formatea un importe en la moneda indicada.
  ///
  /// Si no se especifica [moneda] se usa la moneda predeterminada de la app.
  static String money(double value, {String? moneda}) {
    return _currencyFormat(Moneda.desdeCodigo(moneda)).format(value);
  }

  static String quantity(double value) => _decimal.format(value);
  static String date(DateTime value) => _date.format(value.toLocal());
  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());
  static String shortDate(DateTime value) => _shortDate.format(value.toLocal());
  static String percentage(double value) => '${_decimal.format(value)}%';
}
