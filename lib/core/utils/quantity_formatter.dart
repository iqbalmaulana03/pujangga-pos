class QuantityFormatter {
  QuantityFormatter._();

  static double? parse(String? raw, {bool allowNegative = false}) {
    var text = (raw ?? '').trim();
    final isNegative = allowNegative && text.startsWith('-');
    if (isNegative) text = text.substring(1);
    if (!RegExp(r'^(?:\d+(?:[.,]\d{0,3})?|[.,]\d{1,3})$').hasMatch(text)) {
      return null;
    }
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || !value.isFinite) return null;
    return isNegative ? -value : value;
  }

  static String format(num value) {
    final normalized = value.toDouble();
    if (!normalized.isFinite) return normalized.toString();
    var text = normalized.toStringAsFixed(3);
    text = text.replaceFirst(RegExp(r'\.0+$'), '');
    text = text.replaceFirstMapped(
      RegExp(r'(\.\d*?)0+$'),
      (match) => match[1]!,
    );
    return text.replaceAll('.', ',');
  }
}
