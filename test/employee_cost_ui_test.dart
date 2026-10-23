import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/features/katalog/presentation/pages/item_form_page.dart';
import 'package:pujangga_pos/features/karyawan/domain/entities/employee.dart';
import 'package:pujangga_pos/features/karyawan/presentation/controllers/employee_controller.dart';
import 'package:pujangga_pos/features/karyawan/presentation/pages/karyawan_page.dart';
import 'package:pujangga_pos/features/pengeluaran/presentation/pages/tambah_pengeluaran_page.dart';
import 'package:pujangga_pos/features/pengeluaran/data/repositories/expense_repository.dart';
import 'package:pujangga_pos/shared/widgets/profit_breakdown.dart';

void main() {
  // Providers are overridden; these UI checks never open an application database.
  testWidgets(
    'service zero cost requires explicit choice and disables cost field',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ItemFormPage())),
      );
      await tester.tap(find.text('Layanan'));
      await tester.pumpAndSettle();
      final choice = find.text('Tanpa biaya dasar — Rp0');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      final cost = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((field) => field.enabled == false);
      expect(cost, hasLength(1));
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .where((f) => f.enabled == false),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('commission form offers all three scopes', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [employeesProvider.overrideWith((ref) async => [])],
        child: const MaterialApp(home: KaryawanPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Cakupan komisi'), findsOneWidget);
    await tester.tap(find.text('Barang dan jasa'));
    await tester.pumpAndSettle();
    expect(find.text('Jasa saja'), findsOneWidget);
    expect(find.text('Barang saja'), findsOneWidget);
    await tester.tap(find.text('Jasa saja'));
    await tester.pumpAndSettle();
    expect(find.text('Jasa saja'), findsOneWidget);
  });

  testWidgets(
    'salary selection prefills locked monthly amount and excludes commission employees',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeSalaryForMonthProvider.overrideWith(
              (ref, selection) async => 3000000,
            ),
            activeEmployeesProvider.overrideWith(
              (ref) async => [
                Employee(
                  id: 1,
                  name: 'Gaji',
                  isActive: true,
                  compensationType: 'monthly_salary',
                  monthlySalary: 3000000,
                  effectiveFrom: DateTime(2026),
                ),
                Employee(
                  id: 2,
                  name: 'Komisi',
                  isActive: true,
                  compensationType: 'commission',
                  commissionPercent: 10,
                  effectiveFrom: DateTime(2026),
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: TambahPengeluaranPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Operasional'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gaji Karyawan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      expect(find.text('Komisi'), findsNothing);
      await tester.tap(find.text('Gaji').last);
      await tester.pumpAndSettle();
      final salary = tester
          .widgetList<TextField>(find.byType(TextField))
          .singleWhere((field) => field.readOnly);
      expect(salary.controller!.text, '3000000');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profit shows commission separately without counting twice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfitBreakdown(
            grossMargin: 100000,
            expenses: 40000,
            commissionExpenses: 10000,
            isComplete: true,
            onExpensesTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('- Komisi karyawan'), findsOneWidget);
    expect(find.text('Rp10.000'), findsOneWidget);
    expect(find.text('- Pengeluaran lainnya'), findsOneWidget);
    expect(find.text('Rp30.000'), findsOneWidget);
    expect(find.text('Rp40.000'), findsNothing);
  });
}
