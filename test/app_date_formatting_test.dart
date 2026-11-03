import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart' as reference;
import 'package:intl/date_time_patterns.dart' as reference_patterns;
import 'package:intl/intl.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';

void main() {
  test('registers only application date locales and preserves CLDR data', () {
    initializeAppDateFormatting();
    expect(
      DateFormat.allLocalesWithSymbols(),
      unorderedEquals(['en_US', 'id']),
    );
    final symbols = reference.dateTimeSymbolMap();
    for (final locale in ['en_US', 'id']) {
      expect(
        DateFormat.yMMMMEEEEd(locale).dateSymbols.serializeToMap(),
        symbols[locale]!.serializeToMap(),
      );
      for (final entry
          in reference_patterns.dateTimePatternMap()[locale]!.entries) {
        expect(
          DateFormat(entry.key, locale).pattern,
          entry.value,
          reason: '$locale ${entry.key}',
        );
      }
    }
  });

  test('preserves Indonesian regional fallback, receipts and invoice IDs', () {
    initializeAppDateFormatting();
    final date = DateTime(2026, 11, 3, 14, 5, 6);
    expect(DateFormat('d MMM yyyy', 'id_ID').format(date), '3 Nov 2026');
    expect(
      DateFormat.yMMMMEEEEd('id_ID').format(date),
      'Selasa, 3 November 2026',
    );
    expect(DateFormat.Hm('id_ID').format(date), '14.05');
    expect(
      DateFormat('yyyyMMdd-HHmmss', 'en_US').format(date),
      '20261103-140506',
    );
    expect(DateFormat('dd MMM yyyy', 'en_US').format(date), '03 Nov 2026');
    // Startup may initialize more than once in QA; registration stays usable.
    initializeAppDateFormatting();
    expect(DateFormat.yMMMMd('id_ID').format(date), '3 November 2026');
  });
}
