import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/transaksi_cart_item.dart';
import '../../domain/entities/transaksi_receipt.dart';
import '../../domain/entities/transaksi_submit_request.dart';
import '../models/transaksi_item_db_model.dart';

class TransactionLocalDataSource {
  TransactionLocalDataSource({required this.database});

  final AppDatabase database;

  Future<List<TransaksiItemDbModel>> getCatalogItems() async {
    final db = await database.database();

    final rows = await db.rawQuery('''
      SELECT
        items.*,
        categories.name AS category_name
      FROM items
      LEFT JOIN categories ON categories.id = items.category_id
      WHERE items.is_active = 1
      ORDER BY items.item_type ASC, items.name ASC
    ''');

    return rows.map(TransaksiItemDbModel.fromMap).toList();
  }

  Future<TransaksiReceipt> saveTransaction(
    TransaksiSubmitRequest request,
  ) async {
    final db = await database.database();

    return db.transaction((txn) async {
      final createdAt = DateTime.now();
      final createdAtIso = createdAt.toIso8601String();
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

      final pendingStockMovementIds = <int>[];

      for (final cartItem in request.items) {
        if (!cartItem.item.isBarang) {
          continue;
        }

        final itemId = int.parse(cartItem.item.id);
        final row = await txn.query(
          'items',
          columns: ['stock_qty'],
          where: 'id = ?',
          whereArgs: [itemId],
          limit: 1,
        );

        final currentStock = (row.first['stock_qty'] as num?)?.toDouble() ?? 0;
        final quantity = cartItem.quantity.toDouble();
        if (currentStock < quantity) {
          throw AppException(
            'insufficient_stock',
            'Stok ${cartItem.item.name} tidak cukup untuk transaksi ini.',
          );
        }

        final updatedStock = currentStock - quantity;
        await txn.update(
          'items',
          {'stock_qty': updatedStock, 'updated_at': createdAtIso},
          where: 'id = ?',
          whereArgs: [itemId],
        );

        final movementId = await txn.insert('stock_movements', {
          'item_id': itemId,
          'movement_type': 'sale',
          'qty_change': -quantity,
          'qty_before': currentStock,
          'qty_after': updatedStock,
          'reference_type': 'transaction',
          'reference_id': null,
          'notes': 'Penjualan ${cartItem.item.name}',
          'created_at': createdAtIso,
        });
        pendingStockMovementIds.add(movementId);
      }

      final transactionId = await txn.insert('sales_transactions', {
        'invoice_no': invoiceNumber,
        'transaction_date': createdAtIso,
        'subtotal_amount': subtotalAmount,
        'discount_amount': itemDiscountAmount + request.orderDiscountAmount,
        'tax_amount': request.taxAmount,
        'total_amount': totalAmount,
        'payment_method': _mapUiPaymentMethodToDb(request.paymentMethod),
        'paid_amount': request.cashPaidAmount ?? 0,
        'change_amount': changeAmount,
        'customer_name': null,
        'notes': null,
        'status': 'completed',
        'created_at': createdAtIso,
        'updated_at': createdAtIso,
      });

      for (final cartItem in request.items) {
        final itemRows = await txn.query(
          'items',
          columns: ['harga_modal', 'biaya_dasar'],
          where: 'id = ?',
          whereArgs: [int.parse(cartItem.item.id)],
          limit: 1,
        );
        double? costPrice;
        if (itemRows.isNotEmpty) {
          costPrice = cartItem.item.isJasa
              ? (itemRows.first['biaya_dasar'] as num?)?.toDouble()
              : (itemRows.first['harga_modal'] as num?)?.toDouble();
        }

        await txn.insert('sales_transaction_items', {
          'transaction_id': transactionId,
          'item_id': int.parse(cartItem.item.id),
          'item_name_snapshot': cartItem.item.name,
          'item_type_snapshot': cartItem.item.isJasa ? 'service' : 'product',
          'unit_snapshot': cartItem.item.unitLabel,
          'price_snapshot': cartItem.item.sellingPrice,
          'qty': cartItem.quantity.toDouble(),
          'line_subtotal': cartItem.lineSubtotal,
          'line_discount_amount': cartItem.itemDiscountAmount,
          'line_total': cartItem.lineTotal,
          'cost_price_snapshot': costPrice,
          'created_at': createdAtIso,
        });
      }

      for (final movementId in pendingStockMovementIds) {
        await txn.update(
          'stock_movements',
          {'reference_id': transactionId},
          where: 'id = ?',
          whereArgs: [movementId],
        );
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
      where: 'invoice_no = ?',
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

    final itemDiscountAmount = itemRows.fold<double>(
      0,
      (total, row) => total + (row['line_discount_amount'] as num).toDouble(),
    );
    final totalDiscountAmount = (transaction['discount_amount'] as num)
        .toDouble();
    final orderDiscountAmount = (totalDiscountAmount - itemDiscountAmount)
        .clamp(0, double.infinity)
        .toDouble();

    final items = itemRows
        .map(
          (row) => TransaksiCartItem(
            item: TransaksiItemDbModel(
              id: (row['item_id'] as num).toInt(),
              name: row['item_name_snapshot'] as String,
              category: 'Riwayat',
              itemType: row['item_type_snapshot'] as String,
              sellingPrice: (row['price_snapshot'] as num).toDouble(),
              stockQuantity: null,
              unitLabel: row['unit_snapshot'] as String?,
              isActive: true,
            ).toEntity(),
            quantity: ((row['qty'] as num).toDouble()).toInt(),
            itemDiscountAmount: (row['line_discount_amount'] as num).toDouble(),
          ),
        )
        .toList();

    return TransaksiReceipt(
      invoiceNumber: transaction['invoice_no'] as String,
      createdAt: DateTime.parse(transaction['transaction_date'] as String),
      paymentMethod: _mapDbPaymentMethodToUi(
        transaction['payment_method'] as String,
      ),
      subtotalAmount: (transaction['subtotal_amount'] as num).toDouble(),
      itemDiscountAmount: itemDiscountAmount,
      orderDiscountAmount: orderDiscountAmount,
      taxAmount: (transaction['tax_amount'] as num).toDouble(),
      totalAmount: (transaction['total_amount'] as num).toDouble(),
      changeAmount: (transaction['change_amount'] as num).toDouble(),
      cashPaidAmount: (transaction['paid_amount'] as num?)?.toDouble(),
      status: transaction['status'] as String? ?? 'completed',
      items: items,
    );
  }

  String _generateInvoiceNumber(DateTime createdAt) {
    return 'INV-${DateFormat('yyyyMMdd-HHmmss').format(createdAt)}';
  }

  String _mapUiPaymentMethodToDb(String value) {
    switch (value) {
      case 'tunai':
        return 'cash';
      case 'transfer':
        return 'transfer';
      case 'qris':
        return 'qris';
      case 'ewallet':
        return 'ewallet';
      case 'kartu':
        return 'card';
      default:
        return 'cash';
    }
  }

  String _mapDbPaymentMethodToUi(String value) {
    switch (value) {
      case 'cash':
        return 'tunai';
      case 'transfer':
        return 'transfer';
      case 'qris':
        return 'qris';
      case 'ewallet':
        return 'ewallet';
      case 'card':
        return 'kartu';
      default:
        return 'tunai';
    }
  }
}
