import 'dart:math' as math;

/// Decimal business arithmetic. Doubles are adapters, never accumulators.
class ScaledArithmetic {
  ScaledArithmetic._();

  static const maxUnits = 9007199254740991;
  static final _limit = BigInt.from(maxUnits);

  static int moneyDigits(String currencyCode) => currencyCode == 'IDR' ? 0 : 2;
  static int quantityUnits(num value) => units(value, 3);
  static double quantity(num value) => valueOf(quantityUnits(value), 3);

  /// New input must fit three decimals; legacy reads may contain finer values.
  static double inputQuantity(num value) {
    final result = quantity(value);
    final tolerance = 4 * 2.220446049250313e-16 * math.max(1, value.abs());
    if ((result - value).abs() > tolerance) {
      throw const FormatException('Kuantitas maksimal tiga angka desimal.');
    }
    return result;
  }

  static int moneyUnits(num value, String currencyCode) =>
      units(value, moneyDigits(currencyCode));
  static double money(num value, String currencyCode) =>
      valueOf(moneyUnits(value, currencyCode), moneyDigits(currencyCode));

  static int checked(BigInt value) {
    if (value.abs() > _limit) {
      throw const FormatException('Angka melampaui batas presisi yang aman.');
    }
    return value.toInt();
  }

  static int sum(Iterable<int> values) => checked(
    values.fold(BigInt.zero, (sum, value) => sum + BigInt.from(value)),
  );

  static int units(num value, int digits) {
    final decimal = _Decimal(value);
    return checked(
      _divide(decimal.numerator * _ten(digits), decimal.denominator),
    );
  }

  static double valueOf(int units, int digits) {
    checked(BigInt.from(units));
    final result = units / math.pow(10, digits);
    // REAL must be able to round-trip the selected smallest unit.
    if (ScaledArithmetic.units(result, digits) != units) {
      throw const FormatException(
        'Angka tidak dapat disimpan dengan presisi ini.',
      );
    }
    return result;
  }

  /// Legacy operands can have finer precision. Round their sum only once.
  static double addQuantity(num left, num right) {
    final decimal = _quantitySum(left, right);
    return valueOf(
      checked(_divide(decimal.numerator * _ten(3), decimal.denominator)),
      3,
    );
  }

  /// A legacy ledger must record the actual change, including normalization.
  static double quantityDelta(num before, num after) {
    final decimal = _quantitySum(after, -before);
    // Denominators are powers of ten. Parsing the decimal coefficient/exponent
    // avoids overflowing an intermediate double for tiny legacy operands.
    final result = double.parse(
      '${decimal.numerator}e-${decimal.denominator.toString().length - 1}',
    );
    quantityUnits(result);
    return result;
  }

  static _Decimal _quantitySum(num left, num right) {
    quantityUnits(left);
    quantityUnits(right);
    return _Decimal(left).add(_Decimal(right));
  }

  /// Round only after multiplying price by the normalized quantity.
  static int lineSubtotal(num price, num quantity, String currencyCode) {
    final decimal = _Decimal(price);
    return checked(
      _divide(
        decimal.numerator *
            BigInt.from(quantityUnits(quantity)) *
            _ten(moneyDigits(currencyCode)),
        decimal.denominator * BigInt.from(1000),
      ),
    );
  }

  /// Apply a decimal percent and optional rational allocation, rounding once.
  static int percentage(
    int base,
    num percent, {
    int numerator = 1,
    int denominator = 1,
  }) {
    final decimal = _Decimal(percent);
    return checked(
      _divide(
        BigInt.from(base) * decimal.numerator * BigInt.from(numerator),
        decimal.denominator * BigInt.from(100) * BigInt.from(denominator),
      ),
    );
  }

  /// Compatibility for callers passing an already calculated binary double.
  /// New business calculations use [lineSubtotal] and [percentage] instead.
  static double roundCalculated(num value, String currencyCode) {
    if (!value.isFinite) throw const FormatException('Angka harus terbatas.');
    final digits = moneyDigits(currencyCode);
    final scaled = value * math.pow(10, digits);
    if (!scaled.isFinite || scaled.abs() > maxUnits) {
      throw const FormatException('Angka melampaui batas presisi yang aman.');
    }
    final magnitude = scaled.abs();
    final whole = magnitude.floor();
    final tolerance = math.min(
      1e-7,
      4 * 2.220446049250313e-16 * math.max(1, magnitude),
    );
    if ((magnitude - whole - 0.5).abs() <= tolerance) {
      return valueOf(scaled.isNegative ? -whole - 1 : whole + 1, digits);
    }
    return money(value, currencyCode);
  }

  static BigInt _ten(int power) => BigInt.from(10).pow(power);
  static BigInt _divide(BigInt numerator, BigInt denominator) {
    if (denominator <= BigInt.zero) {
      throw const FormatException('Pembagi tidak valid.');
    }
    final magnitude = numerator.abs();
    var result = magnitude ~/ denominator;
    if ((magnitude % denominator) * BigInt.two >= denominator) {
      result += BigInt.one;
    }
    return numerator.isNegative ? -result : result;
  }
}

class _Decimal {
  _Decimal._(this.numerator, this.denominator);
  _Decimal(num value) {
    if (!value.isFinite) throw const FormatException('Angka harus terbatas.');
    final parts = value.toString().toLowerCase().split('e');
    final exponent = parts.length == 2 ? int.parse(parts[1]) : 0;
    final fraction = parts[0].split('.');
    numerator = BigInt.parse(fraction.join());
    final scale = (fraction.length == 2 ? fraction[1].length : 0) - exponent;
    denominator = scale > 0 ? BigInt.from(10).pow(scale) : BigInt.one;
    if (scale < 0) numerator *= BigInt.from(10).pow(-scale);
  }
  late BigInt numerator;
  late BigInt denominator;

  _Decimal add(_Decimal other) => _Decimal._(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );
}
