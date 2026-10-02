import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';

class AppDatabase {
  AppDatabase({Logger? logger}) : _logger = logger ?? Logger('AppDatabase');

  final Logger _logger;

  static final AppDatabase instance = AppDatabase();

  Database? _database;

  Future<String> databasePath() async {
    final dbPath = await getDatabasesPath();
    return path.join(dbPath, AppConstants.databaseName);
  }

  Future<Database> database() async {
    if (_database != null) {
      return _database!;
    }

    final fullPath = await databasePath();

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

  Future<void> reset() async {
    final existingDatabase = _database;
    final fullPath = await databasePath();

    if (existingDatabase != null && existingDatabase.isOpen) {
      await existingDatabase.close();
    }

    _database = null;
    _logger.info('Deleting database at $fullPath');
    await deleteDatabase(fullPath);
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createBusinessProfileTable(db);
    await _createAppSettingsTable(db);
    await _createCategoriesTable(db);
    await _createItemsTable(db);
    await _createSalesTransactionsTable(db);
    await _createSalesTransactionItemsTable(db);
    await _createStockMovementsTable(db);
    await _createExpensesTable(db);
    await _createCapitalHistoryTable(db);
    await _createIndexes(db);
    await _seedDefaultSettings(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await _migrateToVersion5(db, oldVersion);
    }
    if (oldVersion < 6) {
      await _migrateToVersion6(db);
    }
    if (oldVersion < 7) {
      await _migrateToVersion7(db);
    }
    if (oldVersion < 8) {
      await _migrateToVersion8(db);
    }
    if (oldVersion < 9) {
      await _migrateToVersion9(db);
    }
    if (oldVersion < 10) {
      await _migrateToVersion10(db);
    }
    if (oldVersion < 11) {
      await _migrateToVersion11(db);
    }
    if (oldVersion < 12) {
      await _migrateToVersion12(db);
    }
  }

  Future<void> _migrateToVersion12(Database db) async {
    final existingTables = await _getExistingTables(db);
    if (!existingTables.contains('items')) return;

    final columns = await db.rawQuery('PRAGMA table_info(items)');
    final hasBarcode = columns.any((column) => column['name'] == 'barcode');
    if (!hasBarcode) {
      await db.execute('ALTER TABLE items ADD COLUMN barcode TEXT');
    }
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_items_barcode ON items(barcode) WHERE barcode IS NOT NULL AND barcode != ''",
    );
  }

  Future<void> _migrateToVersion11(Database db) async {
    final existingTables = await _getExistingTables(db);
    if (!existingTables.contains('app_settings')) {
      return;
    }

    final columns = await db.rawQuery('PRAGMA table_info(app_settings)');
    final hasAutoPrintReceipt = columns.any(
      (column) => column['name'] == 'auto_print_receipt',
    );
    if (!hasAutoPrintReceipt) {
      await db.execute(
        'ALTER TABLE app_settings ADD COLUMN auto_print_receipt INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  Future<void> _migrateToVersion10(Database db) async {
    final existingTables = await _getExistingTables(db);
    if (existingTables.contains('sales_transactions')) {
      final columns = await db.rawQuery(
        'PRAGMA table_info(sales_transactions)',
      );
      final hasStatus = columns.any((c) => c['name'] == 'status');
      if (!hasStatus) {
        await db.execute(
          'ALTER TABLE sales_transactions ADD COLUMN status TEXT NOT NULL DEFAULT \'completed\'',
        );
      }
    }
  }

  Future<void> _migrateToVersion8(Database db) async {
    final existingTables = await _getExistingTables(db);
    if (existingTables.contains('items')) {
      final columns = await db.rawQuery('PRAGMA table_info(items)');

      final hasWholesalePrice = columns.any(
        (c) => c['name'] == 'wholesale_price',
      );
      if (!hasWholesalePrice) {
        await db.execute('ALTER TABLE items ADD COLUMN wholesale_price REAL');
      }

      final hasWholesaleMin = columns.any(
        (c) => c['name'] == 'wholesale_min_quantity',
      );
      if (!hasWholesaleMin) {
        await db.execute(
          'ALTER TABLE items ADD COLUMN wholesale_min_quantity INTEGER',
        );
      }
    }
  }

  Future<void> _migrateToVersion9(Database db) async {
    final existingTables = await _getExistingTables(db);
    if (!existingTables.contains('capital_history')) {
      await _createCapitalHistoryTable(db);

      if (existingTables.contains('business_profile')) {
        final profileRows = await db.query('business_profile', limit: 1);
        if (profileRows.isNotEmpty) {
          final profile = profileRows.first;
          final amount = (profile['modal_awal_usaha'] as num?)?.toDouble();
          if (amount != null && amount > 0) {
            await db.insert('capital_history', {
              'amount': amount,
              'created_at': _nowIsoString(),
            });
          }
        }
      }
    }
  }

  Future<void> _migrateToVersion6(Database db) async {
    final existingTables = await _getExistingTables(db);

    if (existingTables.contains('business_profile')) {
      final columns = await db.rawQuery('PRAGMA table_info(business_profile)');
      final hasColumn = columns.any((c) => c['name'] == 'modal_awal_usaha');
      if (!hasColumn) {
        await db.execute(
          'ALTER TABLE business_profile ADD COLUMN modal_awal_usaha REAL',
        );
      }
    }

    if (existingTables.contains('items')) {
      final columns = await db.rawQuery('PRAGMA table_info(items)');
      final hasHargaModal = columns.any((c) => c['name'] == 'harga_modal');
      if (!hasHargaModal) {
        await db.execute('ALTER TABLE items ADD COLUMN harga_modal REAL');
      }
      final hasBiayaDasar = columns.any((c) => c['name'] == 'biaya_dasar');
      if (!hasBiayaDasar) {
        await db.execute('ALTER TABLE items ADD COLUMN biaya_dasar REAL');
      }
    }

    if (existingTables.contains('sales_transaction_items')) {
      final columns = await db.rawQuery(
        'PRAGMA table_info(sales_transaction_items)',
      );
      final hasCostSnapshot = columns.any(
        (c) => c['name'] == 'cost_price_snapshot',
      );
      if (!hasCostSnapshot) {
        await db.execute(
          'ALTER TABLE sales_transaction_items ADD COLUMN cost_price_snapshot REAL',
        );
      }
    }
  }

  Future<void> _migrateToVersion7(Database db) async {
    final existingTables = await _getExistingTables(db);
    if (!existingTables.contains('expenses')) {
      await _createExpensesTable(db);
    }
  }

  Future<void> _migrateToVersion5(Database db, int oldVersion) async {
    final existingTables = await _getExistingTables(db);

    final businessProfileRows = existingTables.contains('business_profile')
        ? await db.query('business_profile')
        : <Map<String, Object?>>[];
    final catalogRows = existingTables.contains('catalog_items')
        ? await db.query('catalog_items', orderBy: 'created_at ASC')
        : <Map<String, Object?>>[];
    final salesRows = existingTables.contains('sales_transactions')
        ? await db.query('sales_transactions', orderBy: 'id ASC')
        : <Map<String, Object?>>[];
    final salesItemRows = existingTables.contains('sales_transaction_items')
        ? await db.query('sales_transaction_items', orderBy: 'id ASC')
        : <Map<String, Object?>>[];

    await db.execute('DROP TABLE IF EXISTS stock_movements');
    await db.execute('DROP TABLE IF EXISTS sales_transaction_items');
    await db.execute('DROP TABLE IF EXISTS sales_transactions');
    await db.execute('DROP TABLE IF EXISTS expenses');
    await db.execute('DROP TABLE IF EXISTS items');
    await db.execute('DROP TABLE IF EXISTS categories');
    await db.execute('DROP TABLE IF EXISTS app_settings');
    await db.execute('DROP TABLE IF EXISTS business_profile');

    await _createBusinessProfileTable(db);
    await _createAppSettingsTable(db);
    await _createCategoriesTable(db);
    await _createItemsTable(db);
    await _createSalesTransactionsTable(db);
    await _createSalesTransactionItemsTable(db);
    await _createStockMovementsTable(db);
    await _createExpensesTable(db);
    await _createIndexes(db);
    await _seedDefaultSettings(db);

    final itemIdMap = <String, int>{};

    for (final row in businessProfileRows) {
      await db.insert('business_profile', {
        'id': (row['id'] as num?)?.toInt() ?? 1,
        'business_name': row['business_name'] as String? ?? '',
        'business_type': row['business_type'] as String? ?? '',
        'owner_name': row['owner_name'] as String?,
        'phone': row['phone'] as String? ?? row['contact_number'] as String?,
        'address': row['address'] as String?,
        'logo_path': row['logo_path'] as String?,
        'created_at': row['created_at'] as String? ?? _nowIsoString(),
        'updated_at': row['updated_at'] as String? ?? _nowIsoString(),
      });
    }

    for (final row in catalogRows) {
      final legacyItemType = row['item_type'] as String? ?? 'barang';
      final dbItemType = _mapUiItemTypeToDb(legacyItemType);
      final categoryName = row['category'] as String? ?? 'Umum';
      final categoryId = await _ensureCategory(
        db,
        name: categoryName,
        itemType: dbItemType,
        createdAt: row['created_at'] as String? ?? _nowIsoString(),
        updatedAt: row['updated_at'] as String? ?? _nowIsoString(),
      );

      final insertedId = await db.insert('items', {
        'category_id': categoryId,
        'name': row['name'] as String? ?? '',
        'sku': row['sku'] as String?,
        'item_type': dbItemType,
        'unit': row['unit_label'] as String?,
        'sale_price': (row['selling_price'] as num?)?.toDouble() ?? 0,
        'stock_qty': legacyItemType == 'barang'
            ? ((row['stock_quantity'] as num?)?.toDouble() ?? 0)
            : 0,
        'is_active': (row['is_active'] as num?)?.toInt() ?? 1,
        'notes': null,
        'created_at': row['created_at'] as String? ?? _nowIsoString(),
        'updated_at': row['updated_at'] as String? ?? _nowIsoString(),
      });

      itemIdMap['${row['id']}'] = insertedId;
    }

    final transactionIdMap = <int, int>{};

    for (final row in salesRows) {
      final insertedId = await db.insert('sales_transactions', {
        'invoice_no':
            row['invoice_no'] as String? ??
            row['invoice_number'] as String? ??
            '',
        'transaction_date':
            row['transaction_date'] as String? ??
            row['created_at'] as String? ??
            _nowIsoString(),
        'subtotal_amount': (row['subtotal_amount'] as num?)?.toDouble() ?? 0,
        'discount_amount':
            ((row['item_discount_amount'] as num?)?.toDouble() ?? 0) +
            ((row['order_discount_amount'] as num?)?.toDouble() ?? 0) +
            ((row['discount_amount'] as num?)?.toDouble() ?? 0),
        'tax_amount': (row['tax_amount'] as num?)?.toDouble() ?? 0,
        'total_amount': (row['total_amount'] as num?)?.toDouble() ?? 0,
        'payment_method': _mapUiPaymentMethodToDb(
          row['payment_method'] as String? ?? 'tunai',
        ),
        'paid_amount':
            (row['paid_amount'] as num?)?.toDouble() ??
            (row['cash_paid_amount'] as num?)?.toDouble() ??
            0,
        'change_amount': (row['change_amount'] as num?)?.toDouble() ?? 0,
        'customer_name': row['customer_name'] as String?,
        'notes': row['notes'] as String?,
        'created_at': row['created_at'] as String? ?? _nowIsoString(),
        'updated_at':
            row['updated_at'] as String? ??
            row['created_at'] as String? ??
            _nowIsoString(),
      });

      transactionIdMap[(row['id'] as num).toInt()] = insertedId;
    }

    for (final row in salesItemRows) {
      final legacyTransactionId = (row['transaction_id'] as num?)?.toInt();
      final mappedTransactionId = legacyTransactionId == null
          ? null
          : transactionIdMap[legacyTransactionId];
      if (mappedTransactionId == null) {
        continue;
      }

      final legacyItemId = '${row['item_id']}';
      final mappedItemId = itemIdMap[legacyItemId];
      if (mappedItemId == null) {
        continue;
      }

      await db.insert('sales_transaction_items', {
        'transaction_id': mappedTransactionId,
        'item_id': mappedItemId,
        'item_name_snapshot':
            row['item_name_snapshot'] as String? ??
            row['item_name'] as String? ??
            '',
        'item_type_snapshot': _mapUiItemTypeToDb(
          row['item_type_snapshot'] as String? ??
              row['item_type'] as String? ??
              'barang',
        ),
        'unit_snapshot':
            row['unit_snapshot'] as String? ?? row['unit_label'] as String?,
        'price_snapshot':
            (row['price_snapshot'] as num?)?.toDouble() ??
            (row['unit_price'] as num?)?.toDouble() ??
            0,
        'qty':
            (row['qty'] as num?)?.toDouble() ??
            (row['quantity'] as num?)?.toDouble() ??
            0,
        'line_subtotal':
            (row['line_subtotal'] as num?)?.toDouble() ??
            (row['line_subtotal_amount'] as num?)?.toDouble() ??
            0,
        'line_discount_amount':
            (row['line_discount_amount'] as num?)?.toDouble() ??
            (row['item_discount_amount'] as num?)?.toDouble() ??
            0,
        'line_total':
            (row['line_total'] as num?)?.toDouble() ??
            (row['line_total_amount'] as num?)?.toDouble() ??
            0,
        'created_at': row['created_at'] as String? ?? _nowIsoString(),
      });
    }

    await _rebuildStockMovementsFromTransactions(db);
  }

  Future<void> _createBusinessProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE business_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_name TEXT NOT NULL,
        business_type TEXT NOT NULL,
        owner_name TEXT,
        phone TEXT,
        address TEXT,
        logo_path TEXT,
        modal_awal_usaha REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createAppSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        currency_code TEXT NOT NULL DEFAULT 'IDR',
        currency_symbol TEXT NOT NULL DEFAULT 'Rp',
        receipt_header TEXT,
        receipt_footer TEXT,
        default_tax_percent REAL NOT NULL DEFAULT 0,
        stock_allow_negative INTEGER NOT NULL DEFAULT 0,
        auto_print_receipt INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        item_type TEXT NOT NULL CHECK(item_type IN ('product', 'service')),
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        name TEXT NOT NULL,
        sku TEXT,
        barcode TEXT,
        item_type TEXT NOT NULL CHECK(item_type IN ('product', 'service')),
        unit TEXT,
        sale_price REAL NOT NULL,
        stock_qty REAL NOT NULL DEFAULT 0,
        harga_modal REAL,
        biaya_dasar REAL,
        is_active INTEGER NOT NULL DEFAULT 1,
        wholesale_price REAL,
        wholesale_min_quantity INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(category_id) REFERENCES categories(id)
      )
    ''');
  }

  Future<void> _createSalesTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE sales_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL,
        transaction_date TEXT NOT NULL,
        subtotal_amount REAL NOT NULL DEFAULT 0,
        discount_amount REAL NOT NULL DEFAULT 0,
        tax_amount REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0,
        change_amount REAL NOT NULL DEFAULT 0,
        customer_name TEXT,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSalesTransactionItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE sales_transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        item_name_snapshot TEXT NOT NULL,
        item_type_snapshot TEXT NOT NULL,
        unit_snapshot TEXT,
        price_snapshot REAL NOT NULL,
        qty REAL NOT NULL,
        line_subtotal REAL NOT NULL,
        line_discount_amount REAL NOT NULL DEFAULT 0,
        line_total REAL NOT NULL,
        cost_price_snapshot REAL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(transaction_id) REFERENCES sales_transactions(id) ON DELETE CASCADE,
        FOREIGN KEY(item_id) REFERENCES items(id)
      )
    ''');
  }

  Future<void> _createStockMovementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL,
        movement_type TEXT NOT NULL,
        qty_change REAL NOT NULL,
        qty_before REAL NOT NULL,
        qty_after REAL NOT NULL,
        reference_type TEXT NOT NULL,
        reference_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(item_id) REFERENCES items(id)
      )
    ''');
  }

  Future<void> _createExpensesTable(Database db) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        notes TEXT,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createCapitalHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE capital_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_transactions_invoice_no ON sales_transactions(invoice_no)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_transactions_transaction_date ON sales_transactions(transaction_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_transaction_items_transaction_id ON sales_transaction_items(transaction_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_transaction_items_item_id ON sales_transaction_items(item_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_items_name ON items(name)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_items_sku ON items(sku) WHERE sku IS NOT NULL AND sku != \'\'',
    );
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_items_barcode ON items(barcode) WHERE barcode IS NOT NULL AND barcode != ''",
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_name_item_type ON categories(name, item_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_item_id ON stock_movements(item_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_created_at ON stock_movements(created_at)',
    );
  }

  Future<void> _seedDefaultSettings(Database db) async {
    final rows = await db.query('app_settings', columns: ['id'], limit: 1);
    if (rows.isNotEmpty) {
      return;
    }

    final timestamp = _nowIsoString();
    await db.insert('app_settings', {
      'currency_code': 'IDR',
      'currency_symbol': 'Rp',
      'receipt_header': null,
      'receipt_footer': null,
      'default_tax_percent': 0,
      'stock_allow_negative': 0,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
  }

  Future<Set<String>> _getExistingTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    return rows
        .map((row) => row['name'] as String)
        .where((name) => !name.startsWith('sqlite_'))
        .toSet();
  }

  Future<int> _ensureCategory(
    Database db, {
    required String name,
    required String itemType,
    required String createdAt,
    required String updatedAt,
  }) async {
    final rows = await db.query(
      'categories',
      columns: ['id'],
      where: 'name = ? AND item_type = ?',
      whereArgs: [name.trim(), itemType],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return (rows.first['id'] as num).toInt();
    }

    return db.insert('categories', {
      'name': name.trim(),
      'item_type': itemType,
      'is_active': 1,
      'created_at': createdAt,
      'updated_at': updatedAt,
    });
  }

  Future<void> _rebuildStockMovementsFromTransactions(Database db) async {
    final itemRows = await db.query(
      'items',
      columns: ['id', 'stock_qty', 'item_type', 'created_at'],
    );

    final currentStocks = <int, double>{};
    for (final row in itemRows) {
      final itemId = (row['id'] as num).toInt();
      currentStocks[itemId] = (row['stock_qty'] as num).toDouble();
    }

    final transactionItemRows = await db.rawQuery('''
      SELECT
        sti.id,
        sti.item_id,
        sti.qty,
        sti.created_at,
        st.id AS transaction_id
      FROM sales_transaction_items sti
      INNER JOIN sales_transactions st ON st.id = sti.transaction_id
      WHERE sti.item_type_snapshot = 'product'
      ORDER BY sti.created_at ASC, sti.id ASC
    ''');

    final totalSoldByItem = <int, double>{};
    for (final row in transactionItemRows) {
      final itemId = (row['item_id'] as num).toInt();
      final qty = (row['qty'] as num).toDouble();
      totalSoldByItem[itemId] = (totalSoldByItem[itemId] ?? 0) + qty;
    }

    final historicalStocks = <int, double>{};
    for (final entry in currentStocks.entries) {
      historicalStocks[entry.key] =
          entry.value + (totalSoldByItem[entry.key] ?? 0);
    }

    for (final row in transactionItemRows) {
      final itemId = (row['item_id'] as num).toInt();
      final qty = (row['qty'] as num).toDouble();
      final before = historicalStocks[itemId] ?? qty;
      final after = before - qty;
      historicalStocks[itemId] = after;

      await db.insert('stock_movements', {
        'item_id': itemId,
        'movement_type': 'sale',
        'qty_change': -qty,
        'qty_before': before,
        'qty_after': after,
        'reference_type': 'transaction',
        'reference_id': (row['transaction_id'] as num).toInt(),
        'notes': 'Migrated from legacy sales transaction history',
        'created_at': row['created_at'] as String? ?? _nowIsoString(),
      });
    }
  }

  String _mapUiItemTypeToDb(String value) {
    switch (value) {
      case 'jasa':
      case 'service':
        return 'service';
      case 'barang':
      case 'product':
      default:
        return 'product';
    }
  }

  String _mapUiPaymentMethodToDb(String value) {
    switch (value) {
      case 'tunai':
      case 'cash':
        return 'cash';
      case 'transfer':
        return 'transfer';
      case 'qris':
        return 'qris';
      case 'ewallet':
      case 'e-wallet':
        return 'ewallet';
      case 'kartu':
      case 'card':
        return 'card';
      default:
        return 'cash';
    }
  }

  String _nowIsoString() => DateTime.now().toIso8601String();
}
