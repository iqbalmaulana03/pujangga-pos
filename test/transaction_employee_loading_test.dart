import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/karyawan/domain/entities/employee.dart';
import 'package:pujangga_pos/features/karyawan/presentation/controllers/employee_controller.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_receipt.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/domain/repositories/transaction_repository.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_page.dart';

class _Repository implements TransactionRepository {
  final saved = <TransaksiSubmitRequest>[];
  @override
  Future<List<TransaksiItem>> getCatalogItems() async => [
    const TransaksiItem(
      id: '1',
      name: 'Jasa E2E',
      category: 'Jasa',
      itemType: 'jasa',
      sellingPrice: 100000,
      isActive: true,
    ),
  ];
  @override
  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) async =>
      null;
  @override
  Future<TransaksiReceipt> saveTransaction(
    TransaksiSubmitRequest request,
  ) async {
    saved.add(request);
    return TransaksiReceipt(
      invoiceNumber: 'TEST-${saved.length}',
      createdAt: DateTime(2026),
      paymentMethod: request.paymentMethod,
      subtotalAmount: 100000,
      itemDiscountAmount: 0,
      orderDiscountAmount: 0,
      taxAmount: 0,
      totalAmount: 100000,
      changeAmount: 0,
      items: request.items,
    );
  }
}

void main() {
  for (final wide in [false, true]) {
    for (final deactivate in [false, true]) {
      testWidgets(
        'employee field matches state after ${deactivate ? 'deactivation' : 'submit'} on ${wide ? 'wide' : 'mobile'} layout',
        (tester) async {
          // Every data provider is overridden; no application database is opened.
          tester.view.physicalSize = Size(wide ? 1400 : 430, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var employees = [
            Employee(
              id: 1,
              name: 'Komisi Jasa',
              isActive: true,
              compensationType: 'commission',
              commissionPercent: 10,
              effectiveFrom: DateTime(2026),
            ),
          ];
          final repository = _Repository();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                businessProfileProvider.overrideWith((ref) async => null),
                transactionRepositoryProvider.overrideWithValue(repository),
                appSettingsProvider.overrideWith(
                  (ref) async => const AppSettings(
                    currencyCode: 'IDR',
                    currencySymbol: 'Rp',
                    defaultTaxPercent: 0,
                    stockAllowNegative: false,
                  ),
                ),
                activeEmployeesProvider.overrideWith((ref) async => employees),
              ],
              child: const MaterialApp(home: Scaffold(body: TransaksiPage())),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Jasa E2E'));
          await tester.pumpAndSettle();
          if (!wide) {
            await tester.tap(find.text('Keranjang'));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byType(DropdownButtonFormField<int?>));
          await tester.pumpAndSettle();
          await tester.tap(find.textContaining('Komisi Jasa').last);
          await tester.pumpAndSettle();
          final container = ProviderScope.containerOf(
            tester.element(find.byType(TransaksiPage)),
          );
          final controller = container.read(
            transaksiControllerProvider.notifier,
          );
          expect(
            container.read(transaksiControllerProvider).requireValue.employeeId,
            1,
          );
          if (deactivate) {
            employees = [];
            container.invalidate(activeEmployeesProvider);
            await tester.pumpAndSettle();
          } else {
            controller.updatePaymentMethod('qris');
            await controller.submit();
            await tester.pumpAndSettle();
            expect(repository.saved.single.employeeId, 1);
            controller.addItem((await repository.getCatalogItems()).single);
            await tester.pumpAndSettle();
            if (!wide) {
              await tester.tap(find.text('Keranjang'));
              await tester.pumpAndSettle();
            }
          }
          expect(
            container.read(transaksiControllerProvider).requireValue.employeeId,
            isNull,
          );
          final field = tester.state<FormFieldState<int?>>(
            find.byType(DropdownButtonFormField<int?>),
          );
          expect(field.value, isNull);
          expect(find.textContaining('Komisi Jasa'), findsNothing);
          if (!deactivate) {
            controller.updatePaymentMethod('qris');
            await controller.submit();
            expect(repository.saved.last.employeeId, isNull);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'employee selection updates in the first open mobile cart after asynchronous loading',
    (tester) async {
      // All data providers are overridden; no SQLite database or external service is opened.
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final employees = Completer<List<Employee>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProfileProvider.overrideWith((ref) async => null),
            transactionRepositoryProvider.overrideWithValue(_Repository()),
            appSettingsProvider.overrideWith(
              (ref) async => const AppSettings(
                currencyCode: 'IDR',
                currencySymbol: 'Rp',
                defaultTaxPercent: 0,
                stockAllowNegative: false,
              ),
            ),
            activeEmployeesProvider.overrideWith((ref) => employees.future),
          ],
          child: const MaterialApp(home: TransaksiPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jasa E2E'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keranjang'));
      await tester.pumpAndSettle();
      expect(find.text('Karyawan (opsional)'), findsNothing);
      employees.complete([
        Employee(
          id: 1,
          name: 'Komisi Jasa',
          isActive: true,
          compensationType: 'commission',
          commissionPercent: 10,
          commissionScope: 'service',
          effectiveFrom: DateTime(2026),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Karyawan (opsional)'), findsOneWidget);
      await tester.tap(find.text('Tanpa karyawan'));
      await tester.pumpAndSettle();
      final choice = find.textContaining('Komisi Jasa');
      expect(choice, findsOneWidget);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TransaksiPage)),
      );
      expect(
        container.read(transaksiControllerProvider).requireValue.employeeId,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
