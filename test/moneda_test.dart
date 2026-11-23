import 'package:cotizador_app/core/moneda.dart';
import 'package:cotizador_app/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Moneda', () {
    test('usa el sol peruano por defecto', () {
      expect(Moneda.predeterminada.codigo, 'PEN');
      expect(Moneda.predeterminada.simbolo, 'S/');
      expect(Moneda.desdeCodigo(null).codigo, 'PEN');
    });

    test('incluye todas las monedas soportadas', () {
      final codigos = Moneda.todas.map((moneda) => moneda.codigo).toList();
      expect(codigos, <String>[
        'PEN',
        'USD',
        'EUR',
        'JPY',
        'GBP',
        'AUD',
        'CAD',
        'CNY',
      ]);
    });

    test('conserva códigos desconocidos de cotizaciones antiguas', () {
      final moneda = Moneda.desdeCodigo('MXN');
      expect(moneda.codigo, 'MXN');
      expect(moneda.simbolo, 'MXN');
    });
  });

  group('AppFormatters.money', () {
    test('formatea en soles peruanos por defecto', () {
      expect(AppFormatters.money(1234.5), contains('S/'));
    });

    test('formatea con el símbolo de la moneda indicada', () {
      expect(AppFormatters.money(1234.5, moneda: 'USD'), contains(r'US$'));
      expect(AppFormatters.money(1234.5, moneda: 'EUR'), contains('€'));
      expect(AppFormatters.money(1234.5, moneda: 'JPY'), contains('¥'));
    });
  });
}
