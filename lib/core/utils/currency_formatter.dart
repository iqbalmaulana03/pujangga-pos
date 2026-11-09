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
    final scaled = value * factor;
    final magnitude = scaled.abs();
    final whole = magnitude.floorToDouble();
    // Tax arithmetic can place a mathematical half unit a few binary rounding
    // errors below .5 (e.g. 1.45 * 0.1 * 100). Snap only that tiny neighborhood
    // to the tie, then round halves away from zero. Cap the tolerance in minor
    // units so large amounts cannot turn it into a material price adjustment.
    const machineEpsilon = 2.220446049250313e-16;
    final tolerance = math.min(
      1e-7,
      4 * machineEpsilon * math.max(1, magnitude),
    );
    if ((magnitude - whole - 0.5).abs() <= tolerance) {
      return scaled.sign * (whole + 1) / factor;
    }
    return scaled.roundToDouble() / factor;
  }
}
