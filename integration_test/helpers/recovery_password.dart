import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> confirmRecoverySnapshot(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(find.text('Lindungi Cadangan'), findsOneWidget);
  expect(find.byType(SwitchListTile), findsNothing);
  await tester.enterText(
    find.byType(TextFormField).first,
    'Synthetic recovery 56',
  );
  await tester.enterText(
    find.byType(TextFormField).last,
    'Synthetic recovery 56',
  );
  await tester.tap(find.text('Cadangkan Terenkripsi'));
  await tester.pump();
}
