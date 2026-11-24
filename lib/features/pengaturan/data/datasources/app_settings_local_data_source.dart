import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../models/app_settings_db_model.dart';

class AppSettingsLocalDataSource {
  const AppSettingsLocalDataSource({required this.database});

  final AppDatabase database;

  Future<AppSettingsDbModel?> getSettings() async {
    final db = await database.database();
    final rows = await db.query('app_settings', limit: 1);
    if (rows.isEmpty) {
      return null;
    }

    return AppSettingsDbModel.fromMap(rows.first);
  }

  Future<void> saveSettings(AppSettingsDbModel settings) => database.runWrite(
    () async {
      final db = await database.database();
      await db.transaction((txn) async {
        final rows = await txn.query('app_settings', limit: 1);
        final currentCode = rows.isEmpty ? 'IDR' : rows.first['currency_code'];
        if (currentCode != settings.currencyCode) {
          final result = await txn.rawQuery('''
          SELECT EXISTS(SELECT 1 FROM items) OR
            EXISTS(SELECT 1 FROM sales_transactions) OR
            EXISTS(SELECT 1 FROM expenses) OR
            EXISTS(SELECT 1 FROM capital_history) OR
            EXISTS(SELECT 1 FROM business_profile
                   WHERE COALESCE(modal_awal_usaha, 0) != 0) AS has_data
        ''');
          if (result.single['has_data'] == 1) {
            throw const AppException(
              'currency_locked',
              'Mata uang tidak dapat diubah setelah data usaha tercatat.',
            );
          }
        }
        if (rows.isEmpty) {
          await txn.insert('app_settings', settings.toMap());
          return;
        }

        final existingId = (rows.first['id'] as num).toInt();
        await txn.update(
          'app_settings',
          {...settings.toMap(), 'id': existingId},
          where: 'id = ?',
          whereArgs: [existingId],
        );
      });
    },
  );
}
