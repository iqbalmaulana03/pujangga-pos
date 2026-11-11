import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/widgets/backup_password_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required bool creating,
    required void Function(BackupProtection?) onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(
                await showDialog<BackupProtection>(
                  context: context,
                  builder: (_) => BackupPasswordDialog(creating: creating),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('encryption defaults on; validates length and confirmation', (
    tester,
  ) async {
    BackupProtection? result;
    await open(tester, creating: true, onResult: (value) => result = value);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(find.textContaining('tidak dapat direset'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'short');
    await tester.tap(find.text('Cadangkan Terenkripsi'));
    await tester.pumpAndSettle();
    expect(find.text('Minimal 12 karakter.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Sandi panjang sintetis',
    );
    await tester.enterText(find.byType(TextFormField).last, 'tidak sama');
    await tester.tap(find.text('Cadangkan Terenkripsi'));
    await tester.pumpAndSettle();
    expect(find.text('Kata sandi tidak sama.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).last,
      'Sandi panjang sintetis',
    );
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.obscureText, isTrue);
      expect(field.enableSuggestions, isFalse);
    }
    await tester.tap(find.text('Cadangkan Terenkripsi'));
    await tester.pumpAndSettle();
    expect(result?.password, 'Sandi panjang sintetis');
  });

  testWidgets(
    'plaintext export requires explicit choice and shows disclosure',
    (tester) async {
      BackupProtection? result;
      await open(tester, creating: true, onResult: (value) => result = value);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.textContaining('gaji karyawan'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Cadangkan Tanpa Enkripsi'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.password, isNull);
    },
  );

  testWidgets(
    'restore accepts existing password; cancel returns no protection',
    (tester) async {
      BackupProtection? result;
      await open(tester, creating: false, onResult: (value) => result = value);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'existing-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Buka Cadangan'));
      await tester.pumpAndSettle();
      expect(result?.password, 'existing-password');
      await open(tester, creating: true, onResult: (value) => result = value);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );
}
