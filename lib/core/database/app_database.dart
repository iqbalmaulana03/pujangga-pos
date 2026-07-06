import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';

class AppDatabase {
  AppDatabase({Logger? logger}) : _logger = logger ?? Logger('AppDatabase');

  final Logger _logger;

  static final AppDatabase instance = AppDatabase();

  Database? _database;

  Future<Database> database() async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final fullPath = path.join(dbPath, AppConstants.databaseName);

    _logger.info('Initializing database at $fullPath');

    _database = await openDatabase(
      fullPath,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );

    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE business_profile (
        id INTEGER PRIMARY KEY,
        business_name TEXT NOT NULL,
        business_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }
}
