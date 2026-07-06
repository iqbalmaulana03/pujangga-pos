import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/transaksi_cart_item.dart';
import '../../domain/entities/transaksi_receipt.dart';
import '../../domain/entities/transaksi_submit_request.dart';
import '../models/transaksi_item_db_model.dart';

class TransactionLocalDataSource {
  TransactionLocalDataSource({required this.database});

  final AppDatabase database;

  static final List<Map<String, Object?>> _seedCatalogItems = [
    {
      'id': 'barang-kopi-susu',
      'name': 'Kopi Susu Literan',
      'category': 'Minuman',
      'item_type': 'barang',
      'selling_price': 78000.0,
      'stock_quantity': 18,
      'unit_label': 'Botol',
      'is_active': 1,
    },
    {
      'id': 'barang-roti-bakar',
      'name': 'Roti Bakar Cokelat',
      'category': 'Makanan',
      'item_type': 'barang',
      'selling_price': 28000.0,
      'stock_quantity': 24,
      'unit_label': 'Porsi',
      'is_active': 1,
    },
    {
      'id': 'barang-pomade',
      'name': 'Pomade Medium Hold',
      'category': 'Produk Tambahan',
      'item_type': 'barang',
      'selling_price': 65000.0,
      'stock_quantity': 10,
      'unit_label': 'Pcs',
      'is_active': 1,
    },
    {
      'id': 'jasa-haircut',
      'name': 'Haircut Reguler',
      'category': 'Layanan',
      'item_type': 'jasa',
      'selling_price': 35000.0,
      'stock_quantity': null,
      'unit_label': 'Layanan',
      'is_active': 1,
    },
    {
      'id': 'jasa-coloring',
      'name': 'Coloring Dasar',
      'category': 'Layanan',
      'item_type': 'jasa',
      'selling_price': 120000.0,
      'stock_quantity': null,
      'unit_label': 'Layanan',
      'is_active': 1,
    },
  ];

  Future<List<TransaksiItemDbModel>> getCatalogItems() async {
    final db = await database.database();
    await _ensureSeedCatalogItems(db);

    final rows = await db.query(
      'catalog_items',
      where: 'is_active = 1',
      orderBy: 'item_type ASC, name ASC',
    );

    return rows.map(TransaksiItemDbModel.fromMap).toList();
  }

  Future<TransaksiReceipt> saveTransaction(
    TransaksiSubmitRequest request,
  ) async {
    final db = await database.database();
    await _ensureSeedCatalogItems(db);

    return db.transaction((txn) async {
      final createdAt = DateTime.now();
      final invoiceNumber = _generateInvoiceNumber(createdAt);
      final subtotalAmount = request.items.fold<double>(
        0,
        (total, item) => total + item.lineSubtotal,
      );
      final itemDiscountAmount = request.items.fold<double>(
        0,
        (total, item) => total + item.itemDiscountAmount,
      );
      final totalAmount =
          subtotalAmount -
          itemDiscountAmount -
          request.orderDiscountAmount +
          request.taxAmount;

      if (totalAmount < 0) {
        throw const AppException(
          'validation_error',
          'Total transaksi tidak boleh negatif.',
        );
      }

      double changeAmount = 0;
      if (request.paymentMethod == 'tunai') {
        final paid = request.cashPaidAmount ?? 0;
        if (paid < totalAmount) {
          throw const AppException(
            'validation_error',
            'Pembayaran tunai belum mencukupi total transaksi.',
          );
        }
        changeAmount = paid - totalAmount;
      }

      for (final cartItem in request.items) {
        if (cartItem.item.isBarang) {
          final row = await txn.query(
            'catalog_items',
            columns: ['stock_quantity'],
            where: 'id = ?',
            whereArgs: [cartItem.item.id],
            limit: 1,
          );

          final currentStock =
              (row.first['stock_quantity'] as num?)?.toInt() ?? 0;
          if (currentStock < cartItem.quantity) {
            throw AppException(
              'insufficient_stock',
              'Stok ${cartItem.item.name} tidak cukup untuk transaksi ini.',
            );
          }

          await txn.update(
            'catalog_items',
            {
              'stock_quantity': currentStock - cartItem.quantity,
              'updated_at': createdAt.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [cartItem.item.id],
          );
        }
      }

      final transactionId = await txn.insert('sales_transactions', {
        'invoice_number': invoiceNumber,
        'subtotal_amount': subtotalAmount,
        'item_discount_amount': itemDiscountAmount,
        'order_discount_amount': request.orderDiscountAmount,
        'tax_amount': request.taxAmount,
        'total_amount': totalAmount,
        'payment_method': request.paymentMethod,
        'cash_paid_amount': request.cashPaidAmount,
        'change_amount': changeAmount,
        'created_at': createdAt.toIso8601String(),
      });

      for (final cartItem in request.items) {
        await txn.insert('sales_transaction_items', {
          'transaction_id': transactionId,
          'item_id': cartItem.item.id,
          'item_name': cartItem.item.name,
          'item_category': cartItem.item.category,
          'item_type': cartItem.item.itemType,
          'unit_price': cartItem.item.sellingPrice,
          'quantity': cartItem.quantity,
          'item_discount_amount': cartItem.itemDiscountAmount,
          'line_subtotal_amount': cartItem.lineSubtotal,
          'line_total_amount': cartItem.lineTotal,
        });
      }

      return TransaksiReceipt(
        invoiceNumber: invoiceNumber,
        createdAt: createdAt,
        paymentMethod: request.paymentMethod,
        subtotalAmount: subtotalAmount,
        itemDiscountAmount: itemDiscountAmount,
        orderDiscountAmount: request.orderDiscountAmount,
        taxAmount: request.taxAmount,
        totalAmount: totalAmount,
        changeAmount: changeAmount,
        cashPaidAmount: request.cashPaidAmount,
        items: request.items,
      );
    });
  }

  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) async {
    final db = await database.database();
    final transactions = await db.query(
      'sales_transactions',
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
      limit: 1,
    );

    if (transactions.isEmpty) {
      return null;
    }

    final transaction = transactions.first;
    final transactionId = (transaction['id'] as num).toInt();
    final itemRows = await db.query(
      'sales_transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'id ASC',
    );

    final items = itemRows
        .map(
          (row) => TransaksiCartItem(
            item: TransaksiItemDbModel(
              id: row['item_id'] as String,
              name: row['item_name'] as String,
              category: row['item_category'] as String,
              itemType: row['item_type'] as String,
              sellingPrice: (row['unit_price'] as num).toDouble(),
              stockQuantity: null,
              unitLabel: null,
              isActive: true,
            ).toEntity(),
            quantity: (row['quantity'] as num).toInt(),
            itemDiscountAmount: (row['item_discount_amount'] as num).toDouble(),
          ),
        )
        .toList();

    return TransaksiReceipt(
      invoiceNumber: transaction['invoice_number'] as String,
      createdAt: DateTime.parse(transaction['created_at'] as String),
      paymentMethod: transaction['payment_method'] as String,
      subtotalAmount: (transaction['subtotal_amount'] as num).toDouble(),
      itemDiscountAmount: (transaction['item_discount_amount'] as num)
          .toDouble(),
      orderDiscountAmount: (transaction['order_discount_amount'] as num)
          .toDouble(),
      taxAmount: (transaction['tax_amount'] as num).toDouble(),
      totalAmount: (transaction['total_amount'] as num).toDouble(),
      changeAmount: (transaction['change_amount'] as num).toDouble(),
      cashPaidAmount: (transaction['cash_paid_amount'] as num?)?.toDouble(),
      items: items,
    );
  }

  Future<void> _ensureSeedCatalogItems(DatabaseExecutor executor) async {
    final rows = await executor.query(
      'catalog_items',
      columns: ['id'],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    for (final item in _seedCatalogItems) {
      await executor.insert('catalog_items', {
        ...item,
        'created_at': timestamp,
        'updated_at': timestamp,
      });
    }
  }

  String _generateInvoiceNumber(DateTime createdAt) {
    return 'INV-${DateFormat('yyyyMMdd-HHmmss').format(createdAt)}';
  }
}
