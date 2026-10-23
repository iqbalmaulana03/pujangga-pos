import 'package:flutter/material.dart';

import '../../core/utils/currency_formatter.dart';

class ProfitBreakdown extends StatelessWidget {
  const ProfitBreakdown({
    required this.grossMargin,
    required this.expenses,
    required this.isComplete,
    required this.onExpensesTap,
    this.expenseLabel = 'Pengeluaran',
    this.commissionExpenses = 0,
    super.key,
  });

  final double grossMargin;
  final double expenses;
  final double commissionExpenses;
  final bool isComplete;
  final VoidCallback onExpensesTap;
  final String expenseLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(
          'Margin kotor',
          isComplete ? CurrencyFormatter.format(grossMargin) : 'Belum lengkap',
        ),
        const SizedBox(height: 4),
        if (commissionExpenses > 0)
          InkWell(
            onTap: onExpensesTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _row(
                '- Komisi karyawan',
                CurrencyFormatter.format(commissionExpenses),
                expense: true,
              ),
            ),
          ),
        InkWell(
          onTap: onExpensesTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _row(
              commissionExpenses > 0
                  ? '- Pengeluaran lainnya'
                  : '- $expenseLabel',
              CurrencyFormatter.format(expenses - commissionExpenses),
              expense: true,
            ),
          ),
        ),
        if (!isComplete)
          const Text(
            'Lengkapi harga modal / biaya dasar untuk menghitung laba.',
            style: TextStyle(fontSize: 11, color: Color(0xFF3F4947)),
          ),
      ],
    );
  }

  Widget _row(String label, String amount, {bool expense = false}) {
    final color = expense ? const Color(0xFFBA1A1A) : const Color(0xFF3F4947);
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 12, color: color)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            amount,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        if (expense)
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF3F4947)),
      ],
    );
  }
}
