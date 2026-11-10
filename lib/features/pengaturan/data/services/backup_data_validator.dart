import '../../../../core/errors/app_exception.dart';

/// Business invariants shared by file inspection and direct restore candidates.
/// Call only after SQLite column types and nullability have been checked.
class BackupDataValidator {
  const BackupDataValidator();

  static const _dateColumns = {
    'created_at',
    'updated_at',
    'transaction_date',
    'expense_date',
    'effective_from',
    'valid_from',
    'valid_until',
  };
  static const _enums = <String, Set<Object>>{
    'item_type': {'product', 'service'},
    'item_type_snapshot': {'product', 'service'},
    'payment_method': {'cash', 'transfer', 'qris', 'ewallet', 'card'},
    'status': {'completed', 'voided'},
    'compensation_type': {'commission', 'monthly_salary'},
    'compensation_type_snapshot': {'commission', 'monthly_salary'},
    'commission_scope': {'all', 'service', 'product'},
    'commission_scope_snapshot': {'all', 'service', 'product'},
    'source_type': {'commission', 'monthly_salary'},
    'movement_type': {
      'sale',
      'void',
      'stock_in',
      'stock_out',
      'manual_add',
      'manual_reduce',
      'set_balance',
      'initial',
    },
    'reference_type': {
      'transaction',
      'initial_stock',
      'catalog_edit',
      'adjustment',
      'item',
    },
    'is_active': {0, 1},
    'stock_allow_negative': {0, 1},
    'auto_print_receipt': {0, 1},
  };
  static const _nonNegative = {
    'modal_awal_usaha',
    'sale_price',
    'harga_modal',
    'biaya_dasar',
    'wholesale_price',
    'subtotal_amount',
    'discount_amount',
    'tax_amount',
    'total_amount',
    'paid_amount',
    'change_amount',
    'commission_amount',
    'price_snapshot',
    'line_subtotal',
    'line_discount_amount',
    'line_total',
    'cost_price_snapshot',
    'commission_percent',
    'commission_percent_snapshot',
    'monthly_salary',
    'monthly_salary_snapshot',
    'default_tax_percent',
  };

  void validate(Map<String, List<Map<String, Object?>>> tables) {
    for (final table in tables.entries) {
      for (final row in table.value) {
        for (final entry in row.entries) {
          final value = entry.value;
          if (value == null) continue;
          final column = entry.key;
          if (_dateColumns.contains(column) && !isValidDate(value as String)) {
            _invalid(table.key, column);
          }
          if (_enums.containsKey(column) && !_enums[column]!.contains(value)) {
            _invalid(table.key, column);
          }
          if (_nonNegative.contains(column) && (value as num) < 0) {
            _invalid(table.key, column);
          }
          if ({'qty', 'wholesale_min_quantity', 'amount'}.contains(column) &&
              (value as num) <= 0) {
            _invalid(table.key, column);
          }
          if ({
                'commission_percent',
                'commission_percent_snapshot',
              }.contains(column) &&
              (value as num) > 100) {
            _invalid(table.key, column);
          }
        }
        if (row['compensation_type'] == 'commission' &&
            table.key == 'employees' &&
            row['commission_percent'] == null) {
          _invalid(table.key, 'commission_percent');
        }
        if (row['compensation_type'] == 'monthly_salary' &&
            ((row['monthly_salary'] as num?) ?? 0) <= 0) {
          _invalid(table.key, 'monthly_salary');
        }
        if (row['valid_until'] != null &&
            !DateTime.parse(row['valid_until'] as String)
                .isAfter(DateTime.parse(row['valid_from'] as String))) {
          _invalid(table.key, 'valid_until');
        }
        if (table.key == 'stock_movements') {
          _equal(
            table.key,
            'qty_after',
            row['qty_after'] as num,
            (row['qty_before'] as num) + (row['qty_change'] as num),
          );
        }
      }
    }
    _validateTransactions(tables);
  }

  void _validateTransactions(Map<String, List<Map<String, Object?>>> tables) {
    final headers = {
      for (final row in tables['sales_transactions']!) row['id']: row,
    };
    final items = {for (final row in tables['items']!) row['id']};
    final lines = <Object?, List<Map<String, Object?>>>{};
    for (final row in tables['sales_transaction_items']!) {
      if (!headers.containsKey(row['transaction_id']) ||
          !items.contains(row['item_id'])) {
        _invalid('sales_transaction_items', 'transaction_id/item_id');
      }
      (lines[row['transaction_id']] ??= []).add(row);
      final subtotal = row['line_subtotal'] as num;
      final discount = row['line_discount_amount'] as num;
      if (discount > subtotal) {
        _invalid('sales_transaction_items', 'line_discount_amount');
      }
      _equal(
        'sales_transaction_items',
        'line_subtotal',
        subtotal,
        (row['price_snapshot'] as num) * (row['qty'] as num),
      );
      _equal(
        'sales_transaction_items',
        'line_total',
        row['line_total'] as num,
        subtotal - discount,
      );
    }
    for (final header in headers.values) {
      final details = lines[header['id']] ?? [];
      if (details.isEmpty) _invalid('sales_transactions', 'detail');
      final subtotal = header['subtotal_amount'] as num;
      final discount = header['discount_amount'] as num;
      final itemDiscount = details.fold<num>(
        0,
        (sum, row) => sum + (row['line_discount_amount'] as num),
      );
      if (discount > subtotal || discount + 0.000001 < itemDiscount) {
        _invalid('sales_transactions', 'discount_amount');
      }
      _equal(
        'sales_transactions',
        'subtotal_amount',
        subtotal,
        details.fold<num>(0, (sum, row) => sum + (row['line_subtotal'] as num)),
      );
      final total = header['total_amount'] as num;
      _equal(
        'sales_transactions',
        'total_amount',
        total,
        subtotal - discount + (header['tax_amount'] as num),
      );
      if (header['payment_method'] == 'cash') {
        final paid = header['paid_amount'] as num;
        if (paid < total) _invalid('sales_transactions', 'paid_amount');
        _equal(
          'sales_transactions',
          'change_amount',
          header['change_amount'] as num,
          paid - total,
        );
      }
    }
  }

  // DateTime.tryParse normalizes overflow (e.g. February 30). Check calendar
  // and clock components first, preserving local, UTC and offset ISO dates.
  static bool isValidDate(String value) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?(?:[Zz]|[+-](\d{2}):?(\d{2}))?)?$',
    ).firstMatch(value);
    if (match == null || DateTime.tryParse(value) == null) return false;
    int part(int index, [int fallback = 0]) =>
        int.tryParse(match.group(index) ?? '') ?? fallback;
    final year = part(1);
    final month = part(2);
    final day = part(3);
    return year > 0 &&
        month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= DateTime.utc(year, month + 1, 0).day &&
        part(4) < 24 &&
        part(5) < 60 &&
        part(6) < 60 &&
        part(7) < 24 &&
        part(8) < 60;
  }

  void _equal(String table, String column, num actual, num expected) {
    // Permit floating-point arithmetic noise, not rounded currency differences.
    if (!expected.isFinite ||
        (actual - expected).abs() > 0.000001 + expected.abs() * 1e-12) {
      _invalid(table, column);
    }
  }

  Never _invalid(String table, String column) => throw AppException(
    'backup_invalid',
    'Nilai kolom $column pada tabel $table tidak valid atau tidak konsisten.',
  );
}
