import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/stock_policy.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/scaled_arithmetic.dart';
import '../../domain/services/transaction_calculator.dart';
import '../../domain/entities/transaksi_cart_item.dart';
import '../../domain/entities/transaksi_receipt.dart';
import '../../domain/entities/transaksi_submit_request.dart';
import '../../domain/entities/transaction_validation.dart';
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
  ) => database.runWrite(() async {
    final db = await database.database();

    try {
      return await db.transaction((txn) async {
        // Read and write under the same SQLite transaction, before any effects.
        final existing = await txn.query(
          'sales_transactions',
          columns: ['invoice_no'],
          where: 'checkout_id = ?',
          whereArgs: [request.checkoutId],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return (await _getReceiptByInvoice(
            txn,
            existing.single['invoice_no'] as String,
          ))!;
        }
        final createdAt = DateTime.now();
        final createdAtIso = createdAt.toIso8601String();
        final invoiceNumber = await _generateInvoiceNumber(txn, createdAt);
        final settings = await txn.query(
          'app_settings',
          columns: ['currency_code'],
          limit: 1,
        );
        final currency = settings.isEmpty
            ? 'IDR'
            : settings.single['currency_code'] as String;
        if (currency != request.currencyCode || request.items.isEmpty) {
          throw const AppException(
            'validation_error',
            'Mata uang berubah atau keranjang kosong. Muat ulang transaksi.',
          );
        }
        // Recompute every line; request snapshots must not bypass validation.
        final items = request.items.map((line) {
          if (!line.quantity.isFinite ||
              line.quantity <= 0 ||
              !line.unitPrice.isFinite ||
              line.unitPrice < 0 ||
              !line.itemDiscountAmount.isFinite ||
              line.itemDiscountAmount < 0) {
            throw const AppException(
              'validation_error',
              'Kuantitas, harga, atau diskon item tidak valid.',
            );
          }
          final quantity = ScaledArithmetic.inputQuantity(line.quantity);
          if (quantity <= 0) {
            throw const AppException(
              'validation_error',
              'Kuantitas maksimal tiga angka desimal.',
            );
          }
          final normalized = line.copyWith(
            quantity: quantity,
            currencyCode: currency,
            itemDiscountAmount: ScaledArithmetic.money(
              line.itemDiscountAmount,
              currency,
            ),
          );
          if (normalized.totalUnits(currency) < 0) {
            throw const AppException(
              'validation_error',
              'Diskon item melebihi subtotal.',
            );
          }
          return normalized;
        }).toList();
        final error = TransactionValidation.error(
          items: items,
          currencyCode: currency,
          orderDiscount: request.orderDiscountAmount,
          tax: request.taxAmount,
          paymentMethod: request.paymentMethod,
          cashPaid: request.cashPaidAmount,
        );
        if (error != null) throw AppException('validation_error', error);
        final calculation = TransactionCalculation(
          items: items,
          currencyCode: currency,
          orderDiscount: request.orderDiscountAmount,
          tax: request.taxAmount,
          paid: request.paymentMethod == 'tunai'
              ? request.cashPaidAmount
              : null,
        );
        if (request.orderDiscountAmount < 0 ||
            request.taxAmount < 0 ||
            (request.paymentMethod == 'tunai' &&
                request.cashPaidAmount != null &&
                request.cashPaidAmount! < 0) ||
            calculation.net < 0 ||
            calculation.total < 0 ||
            (request.paymentMethod == 'tunai' && calculation.change < 0)) {
          throw const AppException(
            'validation_error',
            'Diskon, pajak, atau pembayaran tidak valid.',
          );
        }
        final subtotalAmount = calculation.amount(calculation.subtotal);
        final itemDiscountAmount = calculation.amount(calculation.itemDiscount);
        final orderDiscountAmount = calculation.amount(
          calculation.orderDiscountUnits,
        );
        final taxAmount = calculation.amount(calculation.taxUnits);
        final totalAmount = calculation.amount(calculation.total);
        final paidAmount = calculation.amount(calculation.paidUnits);
        final changeAmount = request.paymentMethod == 'tunai'
            ? calculation.amount(calculation.change)
            : 0.0;

        Map<String, Object?>? employeeSnapshot;
        double commission = 0;
        if (request.employeeId != null) {
          final employeeRows = await txn.query(
            'employees',
            where: 'id = ? AND is_active = 1',
            whereArgs: [request.employeeId],
            limit: 1,
          );
          if (employeeRows.isEmpty) {
            throw const AppException(
              'employee_unavailable',
              'Karyawan terpilih sudah tidak aktif atau tidak tersedia. Pilih ulang karyawan sebelum menyimpan transaksi.',
            );
          }
          final employee = employeeRows.single;
          final type = employee['compensation_type'] as String;
          final percent = (employee['commission_percent'] as num?)?.toDouble();
          final salary = (employee['monthly_salary'] as num?)?.toDouble();
          final scope = employee['commission_scope'] as String? ?? 'all';
          TransactionValidation.requireFinite(percent);
          TransactionValidation.requireFinite(salary);
          final netSales = ScaledArithmetic.sum([
            calculation.subtotal,
            -calculation.itemDiscount,
          ]);
          final eligibleSales = ScaledArithmetic.sum(
            items
                .where(
                  (line) =>
                      scope == 'all' ||
                      (scope == 'service' && line.item.isJasa) ||
                      (scope == 'product' && line.item.isBarang),
                )
                .map((line) => line.totalUnits(currency)),
          );
          final rate = (percent ?? 0) < 0 ? 0 : (percent ?? 0);
          // Allocate the order discount and apply percent, rounding only once.
          commission = type == 'commission' && netSales > 0
              ? calculation.amount(
                  ScaledArithmetic.percentage(
                    eligibleSales,
                    rate,
                    numerator: calculation.net,
                    denominator: netSales,
                  ),
                )
              : 0;
          employeeSnapshot = {
            'employee_id': request.employeeId,
            'employee_name_snapshot': employee['name'],
            'compensation_type_snapshot': type,
            'commission_percent_snapshot': percent,
            'commission_scope_snapshot': scope,
            'monthly_salary_snapshot': salary,
            'commission_amount': commission,
          };
        }
        final costPrices = <double?>[];
        for (final line in items) {
          final rows = await txn.query(
            'items',
            columns: ['harga_modal', 'biaya_dasar'],
            where: 'id = ?',
            whereArgs: [int.parse(line.item.id)],
            limit: 1,
          );
          final cost = rows.isEmpty
              ? null
              : (rows.single[line.item.isJasa ? 'biaya_dasar' : 'harga_modal']
                        as num?)
                    ?.toDouble();
          TransactionValidation.requireFinite(cost);
          costPrices.add(cost);
        }

        final allowNegative = await allowsNegativeStock(txn);
        final pendingStockMovementIds = <int>[];

        for (final cartItem in items) {
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

          final currentStock = ((row.first['stock_qty'] as num?) ?? 0)
              .toDouble();
          ScaledArithmetic.quantityUnits(currentStock);
          final quantity = cartItem.quantity.toDouble();
          if (!allowNegative && currentStock < quantity) {
            throw AppException(
              'insufficient_stock',
              'Stok ${cartItem.item.name} tidak cukup untuk transaksi ini.',
            );
          }

          final updatedStock = ScaledArithmetic.addQuantity(
            currentStock,
            -quantity,
          );
          await txn.update(
            'items',
            {'stock_qty': updatedStock, 'updated_at': createdAtIso},
            where: 'id = ?',
            whereArgs: [itemId],
          );

          final movementId = await txn.insert('stock_movements', {
            'item_id': itemId,
            'movement_type': 'sale',
            'qty_change': ScaledArithmetic.quantityDelta(
              currentStock,
              updatedStock,
            ),
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
          'checkout_id': request.checkoutId,
          'invoice_no': invoiceNumber,
          'transaction_date': createdAtIso,
          'subtotal_amount': subtotalAmount,
          'discount_amount': calculation.amount(
            ScaledArithmetic.sum([
              calculation.itemDiscount,
              calculation.orderDiscountUnits,
            ]),
          ),
          'tax_amount': taxAmount,
          'total_amount': totalAmount,
          'payment_method': _mapUiPaymentMethodToDb(request.paymentMethod),
          'paid_amount': paidAmount,
          'change_amount': changeAmount,
          'customer_name': null,
          'notes': null,
          'status': 'completed',
          'created_at': createdAtIso,
          'updated_at': createdAtIso,
        });

        if (employeeSnapshot != null) {
          await txn.update(
            'sales_transactions',
            employeeSnapshot,
            where: 'id = ?',
            whereArgs: [transactionId],
          );
          if (commission > 0) {
            await txn.insert('expenses', {
              'amount': commission,
              'category': 'Komisi Karyawan',
              'notes':
                  'Komisi ${employeeSnapshot['employee_name_snapshot']} - $invoiceNumber',
              'expense_date': createdAtIso,
              'created_at': createdAtIso,
              'updated_at': createdAtIso,
              'source_type': 'commission',
              'source_id': transactionId,
              'employee_id': request.employeeId,
              'period_key': null,
            });
          }
        }

        for (var index = 0; index < items.length; index++) {
          final cartItem = items[index];
          final costPrice = costPrices[index];

          await txn.insert('sales_transaction_items', {
            'transaction_id': transactionId,
            'item_id': int.parse(cartItem.item.id),
            'item_name_snapshot': cartItem.item.name,
            'item_type_snapshot': cartItem.item.isJasa ? 'service' : 'product',
            'unit_snapshot': cartItem.item.unitLabel,
            'price_snapshot': cartItem.unitPrice,
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

        final saved = (await txn.query(
          'sales_transactions',
          where: 'id = ?',
          whereArgs: [transactionId],
          limit: 1,
        )).single;
        return TransaksiReceipt(
          employeeName: saved['employee_name_snapshot'] as String?,
          compensationType: saved['compensation_type_snapshot'] as String?,
          commissionPercent: (saved['commission_percent_snapshot'] as num?)
              ?.toDouble(),
          commissionScope:
              saved['commission_scope_snapshot'] as String? ?? 'all',
          commissionAmount:
              (saved['commission_amount'] as num?)?.toDouble() ?? 0,
          invoiceNumber: invoiceNumber,
          createdAt: createdAt,
          paymentMethod: request.paymentMethod,
          subtotalAmount: subtotalAmount,
          itemDiscountAmount: itemDiscountAmount,
          orderDiscountAmount: orderDiscountAmount,
          taxAmount: taxAmount,
          totalAmount: totalAmount,
          changeAmount: changeAmount,
          cashPaidAmount: request.paymentMethod == 'tunai' ? paidAmount : null,
          items: items,
        );
      });
    } on FormatException {
      throw const AppException(
        'validation_error',
        'Angka tidak valid atau melampaui batas presisi yang aman.',
      );
    }
  });

  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) async {
    final db = await database.database();
    return _getReceiptByInvoice(db, invoiceNumber);
  }

  Future<TransaksiReceipt?> _getReceiptByInvoice(
    DatabaseExecutor db,
    String invoiceNumber,
  ) async {
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
            savedLineSubtotal: (row['line_subtotal'] as num).toDouble(),
            savedLineTotal: (row['line_total'] as num).toDouble(),
            quantity: (row['qty'] as num).toDouble(),
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
      employeeName: transaction['employee_name_snapshot'] as String?,
      compensationType: transaction['compensation_type_snapshot'] as String?,
      commissionPercent: (transaction['commission_percent_snapshot'] as num?)
          ?.toDouble(),
      commissionScope:
          transaction['commission_scope_snapshot'] as String? ?? 'all',
      commissionAmount:
          (transaction['commission_amount'] as num?)?.toDouble() ?? 0,
      items: items,
    );
  }

  Future<String> _generateInvoiceNumber(dynamic txn, DateTime createdAt) async {
    final timestamp = DateFormat('yyyyMMdd-HHmmss').format(createdAt);
    final baseMicros = createdAt.microsecond;
    var sequence = 0;
    while (true) {
      final micros = (baseMicros + sequence) % 1000000;
      final invoice = 'INV-$timestamp-${micros.toString().padLeft(6, '0')}';
      final existing = await txn.query(
        'sales_transactions',
        columns: ['id'],
        where: 'invoice_no = ?',
        whereArgs: [invoice],
        limit: 1,
      );
      if (existing.isEmpty) return invoice;
      sequence++;
    }
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
