import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/utils/quantity_formatter.dart';

void main() {
  test('memformat kuantitas pecahan tanpa nol yang tidak diperlukan', () {
    expect(QuantityFormatter.format(1), '1');
    expect(QuantityFormatter.format(1.5), '1,5');
    expect(QuantityFormatter.format(1.25), '1,25');
    expect(QuantityFormatter.format(1.234), '1,234');
  });

  test('menerima koma dan titik dengan batas tiga angka desimal', () {
    expect(QuantityFormatter.parse('0,25'), 0.25);
    expect(QuantityFormatter.parse('1.5'), 1.5);
    expect(QuantityFormatter.parse('1,234'), 1.234);
    expect(QuantityFormatter.parse('1,2345'), isNull);
    expect(QuantityFormatter.parse('teks'), isNull);
  });

  test('menerima tanda minus hanya bila diizinkan', () {
    expect(QuantityFormatter.parse('-0,125'), isNull);
    expect(QuantityFormatter.parse('-0,125', allowNegative: true), -0.125);
    expect(QuantityFormatter.parse('-.5', allowNegative: true), -0.5);
    expect(QuantityFormatter.parse('-0,1234', allowNegative: true), isNull);
    expect(QuantityFormatter.parse('--1', allowNegative: true), isNull);
    expect(QuantityFormatter.format(-0.125), '-0,125');
  });
}
