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
    final rows = await db.query('business_profile', columns: ['id', 'modal_awal_usaha'], limit: 1);

    if (rows.isEmpty) {
      await db.insert(
        'business_profile',
        profile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      if (profile.modalAwalUsaha != null && profile.modalAwalUsaha! > 0) {
        await db.insert('capital_history', {
          'amount': profile.modalAwalUsaha!,
          'created_at': DateTime.now().toIso8601String(),
          'notes': 'Initial Setup'
        });
      }
      return;
    }

    final existingId = (rows.first['id'] as num).toInt();
    final oldModal = (rows.first['modal_awal_usaha'] as num?)?.toDouble() ?? 0.0;
    final newModal = profile.modalAwalUsaha ?? 0.0;

    await db.update(
      'business_profile',
      {
        ...profile.toMap(),
        'id': existingId,
      },
      where: 'id = ?',
      whereArgs: [existingId],
    );
    
    if (oldModal != newModal && newModal > 0) {
      await db.insert('capital_history', {
        'amount': newModal,
        'created_at': DateTime.now().toIso8601String(),
        'notes': 'Capital Update'
      });
    }
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
