import '../../../../core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

import '../models/business_profile_db_model.dart';

class BusinessProfileLocalDataSource {
  const BusinessProfileLocalDataSource({required this.database});

  final AppDatabase database;

  Future<bool> hasProfile() async {
    final db = await database.database();
    final rows = await db.query('business_profile', columns: ['id'], limit: 1);

    return rows.isNotEmpty;
  }

  Future<void> saveProfile(BusinessProfileDbModel profile) async {
    final db = await database.database();
    await db.insert(
      'business_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<BusinessProfileDbModel?> getProfile() async {
    final db = await database.database();
    final rows = await db.query('business_profile', limit: 1);

    if (rows.isEmpty) {
      return null;
    }

    return BusinessProfileDbModel.fromMap(rows.first);
  }
}
