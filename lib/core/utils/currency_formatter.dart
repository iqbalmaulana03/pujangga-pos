import 'dart:math' as math;

import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String _currencyCode = 'IDR';
  static String _currencySymbol = 'Rp';

  static int _digitsFor(String currencyCode) => currencyCode == 'IDR' ? 0 : 2;
  static int get _decimalDigits => _digitsFor(_currencyCode);
  static String get symbol => _currencySymbol;
  static String get _locale => switch (_currencyCode) {
    'USD' => 'en_US',
    'SGD' => 'en_SG',
    _ => 'id_ID',
  };

  static void configure({
    required String currencyCode,
    required String currencySymbol,
  }) {
    _currencyCode = currencyCode;
    _currencySymbol = currencySymbol;
  }

  static String format(num value) => NumberFormat.currency(
    locale: _locale,
    symbol: _currencySymbol,
    decimalDigits: _decimalDigits,
  ).format(value);

  static String formatNoSymbol(num value) => NumberFormat.currency(
    locale: _locale,
    symbol: '',
    decimalDigits: _decimalDigits,
  ).format(value).trim();

  /// Plain decimal text that can be parsed back by numeric form fields.
  static String formatForInput(num value) =>
      value.toStringAsFixed(_decimalDigits);

  /// Round calculated amounts to the currency's smallest supported unit.
  static double round(num value, {required String currencyCode}) {
    final factor = math.pow(10, _digitsFor(currencyCode));
    return (value * factor).roundToDouble() / factor;
  }
}
