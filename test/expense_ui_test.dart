import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pujangga_pos/features/pengeluaran/data/repositories/expense_repository.dart';
import 'package:pujangga_pos/features/pengeluaran/presentation/pages/pengeluaran_page.dart';
import 'package:pujangga_pos/shared/widgets/profit_breakdown.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('known expenses remain visible when margin is incomplete', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfitBreakdown(
            grossMargin: 100000,
            expenses: 12345,
            isComplete: false,
            expenseLabel: 'Pengeluaran hari ini',
            onExpensesTap: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.text('- Pengeluaran hari ini'), findsOneWidget);
    expect(find.text('Rp12.345'), findsOneWidget);
    expect(find.text('Belum lengkap'), findsOneWidget);
    expect(find.text('Rp100.000'), findsNothing);
    await tester.tap(find.text('- Pengeluaran hari ini'));
    expect(opened, isTrue);
  });

  testWidgets(
    'separate expense menu has period filters, total, empty state and add action',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const PengeluaranPage()),
          GoRoute(
            path: '/add-expense',
            builder: (_, _) => const Scaffold(body: Text('Form Pengeluaran')),
          ),
        ],
      );
      addTearDown(router.dispose);
      // Entire family is overridden: this widget test never opens an application database.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseEntriesProvider.overrideWith(
              (ref, range) async => range.$1 == today
                  ? []
                  : [
                      {
                        'amount': 10000.0,
                        'category': 'Komisi Karyawan',
                        'notes': 'Komisi karyawan',
                        'expense_date': today.toIso8601String(),
                      },
                      {
                        'amount': 3000000.0,
                        'category': 'Gaji Karyawan',
                        'notes': 'Gaji karyawan',
                        'expense_date': today.toIso8601String(),
                      },
                    ],
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Rp3.010.000'), findsOneWidget);
      expect(find.text('Komisi Karyawan'), findsOneWidget);
      expect(find.text('Gaji Karyawan'), findsOneWidget);
      await tester.tap(find.text('Hari ini'));
      await tester.pumpAndSettle();
      expect(find.text('Rp0'), findsOneWidget);
      expect(
        find.text('Belum ada pengeluaran pada periode ini.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tambah Pengeluaran'));
      await tester.pumpAndSettle();
      expect(find.text('Form Pengeluaran'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
