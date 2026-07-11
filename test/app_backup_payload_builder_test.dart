import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/constants/app_constants.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_payload_builder.dart';

void main() {
  test('membangun payload backup yang stabil untuk restore', () {
    const builder = AppBackupPayloadBuilder();
    final generatedAt = DateTime.utc(2026, 7, 12, 3, 45, 0);
    final tables = <String, List<Map<String, Object?>>>{
      'business_profile': [
        {'id': 1, 'business_name': 'Pujangga Coffee'},
      ],
      'items': [
        {'id': 10, 'name': 'Kopi Aren', 'sale_price': 18000.0},
        {'id': 11, 'name': 'Haircut', 'sale_price': 35000.0},
      ],
      'sales_transactions': const [],
    };

    final payload = builder.build(generatedAt: generatedAt, tables: tables);

    expect(payload['format'], AppBackupPayloadBuilder.backupFormat);
    expect(
      payload['format_version'],
      AppBackupPayloadBuilder.backupFormatVersion,
    );

    final database = payload['database'] as Map<String, Object?>;
    expect(database['name'], AppConstants.databaseName);
    expect(database['schema_version'], AppConstants.databaseVersion);

    final tableCounts = payload['table_counts'] as Map<String, Object?>;
    expect(tableCounts['business_profile'], 1);
    expect(tableCounts['items'], 2);
    expect(tableCounts['sales_transactions'], 0);

    final restoredTables = payload['tables'] as Map<String, Object?>;
    expect(restoredTables['items'], [
      {'id': 10, 'name': 'Kopi Aren', 'sale_price': 18000.0},
      {'id': 11, 'name': 'Haircut', 'sale_price': 35000.0},
    ]);
  });
}
