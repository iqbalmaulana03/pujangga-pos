import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/shared/widgets/barcode_scanner_page.dart';

class _LifecycleBinding extends AutomatedTestWidgetsFlutterBinding {
  AppLifecycleState? initialState;

  @override
  AppLifecycleState? get lifecycleState => initialState;
}

void main() {
  final binding = _LifecycleBinding();
  const channel = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );

  for (final state in [
    null,
    AppLifecycleState.resumed,
    AppLifecycleState.paused,
  ]) {
    testWidgets('scanner initial activation with lifecycle $state', (
      tester,
    ) async {
      binding.initialState = state;
      var permissionChecks = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'state') {
          permissionChecks++;
          return 0;
        }
        // Deny permission: no native camera or database is used by this test.
        if (call.method == 'request') return false;
        return null;
      });
      addTearDown(() {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      var released = false;
      await tester.pumpWidget(
        MaterialApp(
          home: BarcodeScannerPage(onReleased: () => released = true),
        ),
      );
      await tester.pumpAndSettle();
      expect(permissionChecks, state == AppLifecycleState.paused ? 0 : 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(released, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
