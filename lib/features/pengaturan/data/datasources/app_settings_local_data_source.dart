import '../../../../core/database/app_database.dart';
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

  Future<void> saveSettings(AppSettingsDbModel settings) async {
    final db = await database.database();
    final rows = await db.query('app_settings', columns: ['id'], limit: 1);
    if (rows.isEmpty) {
      await db.insert('app_settings', settings.toMap());
      return;
    }

    final existingId = (rows.first['id'] as num).toInt();
    await db.update(
      'app_settings',
      {...settings.toMap(), 'id': existingId},
      where: 'id = ?',
      whereArgs: [existingId],
    );
  }
}
