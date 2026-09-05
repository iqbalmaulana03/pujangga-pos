import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(database: AppDatabase.instance);
});

class ExpenseRepository {
  const ExpenseRepository({required this.database});

  final AppDatabase database;

  Future<void> addExpense({
    required double amount,
    required String category,
    required DateTime date,
    String? notes,
  }) async {
    final db = await database.database();
    final timestamp = DateTime.now().toIso8601String();
    
    await db.insert('expenses', {
      'amount': amount,
      'category': category,
      'notes': notes,
      'expense_date': date.toIso8601String(),
      'created_at': timestamp,
      'updated_at': timestamp,
    });
  }
}
