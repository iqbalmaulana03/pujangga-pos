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
      onUpgrade: _onUpgrade,
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
        address TEXT,
        contact_number TEXT,
        owner_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _createCatalogItemsTable(db);
    await _createSalesTransactionsTable(db);
    await _createSalesTransactionItemsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE business_profile ADD COLUMN address TEXT');
      await db.execute(
        'ALTER TABLE business_profile ADD COLUMN contact_number TEXT',
      );
      await db.execute(
        'ALTER TABLE business_profile ADD COLUMN owner_name TEXT',
      );
    }

    if (oldVersion < 3) {
      await _createCatalogItemsTable(db);
      await _createSalesTransactionsTable(db);
      await _createSalesTransactionItemsTable(db);
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE catalog_items ADD COLUMN sku TEXT');
    }
  }

  Future<void> _createCatalogItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS catalog_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        item_type TEXT NOT NULL,
        selling_price REAL NOT NULL,
        sku TEXT,
        stock_quantity INTEGER,
        unit_label TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSalesTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        subtotal_amount REAL NOT NULL,
        item_discount_amount REAL NOT NULL,
        order_discount_amount REAL NOT NULL,
        tax_amount REAL NOT NULL,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        cash_paid_amount REAL,
        change_amount REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSalesTransactionItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        item_id TEXT NOT NULL,
        item_name TEXT NOT NULL,
        item_category TEXT NOT NULL,
        item_type TEXT NOT NULL,
        unit_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        item_discount_amount REAL NOT NULL,
        line_subtotal_amount REAL NOT NULL,
        line_total_amount REAL NOT NULL,
        FOREIGN KEY(transaction_id) REFERENCES sales_transactions(id) ON DELETE CASCADE
      )
    ''');
  }
}
