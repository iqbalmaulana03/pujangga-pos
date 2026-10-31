import 'dart:async';

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

  testWidgets('page release waits for the native camera stop response', (
    tester,
  ) async {
    binding.initialState = AppLifecycleState.resumed;
    final stopped = Completer<void>();
    final calls = <String>[];
    var nativeStarted = false;
    var released = false;
    const events = MethodChannel(
      'dev.steenbakker.mobile_scanner/scanner/event',
    );
    const orientation = MethodChannel(
      'dev.steenbakker.mobile_scanner/scanner/deviceOrientation',
    );
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(orientation, (_) async => null);
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'state') return 1;
      if (call.method == 'start') {
        nativeStarted = true;
        calls.add('start');
        return {
          'textureId': 1,
          'cameraDirection': 1,
          'size': {'width': 640.0, 'height': 480.0},
          'handlesCropAndRotation': true,
          'naturalDeviceOrientation': 'PORTRAIT_UP',
          'sensorOrientation': 90,
        };
      }
      // mobile_scanner 7.4.2 uses the method channel's `stop` method;
      // its dispose() also awaits stop(), rather than a native `dispose` call.
      if (call.method == 'stop') {
        // The plugin also sends a force-stop before its initial start.
        if (!nativeStarted) return null;
        calls.add('stop');
        await stopped.future;
        calls.add('stopped');
      }
      return null;
    });
    addTearDown(() {
      if (!stopped.isCompleted) stopped.complete();
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(events, null);
      messenger.setMockMethodCallHandler(orientation, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: BarcodeScannerPage(
          onReleased: () {
            calls.add('released');
            released = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, ['start']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls, ['start', 'stop']);
    expect(released, isFalse);

    stopped.complete();
    await tester.pumpAndSettle();
    expect(calls, ['start', 'stop', 'stopped', 'released']);
    expect(released, isTrue);
    expect(tester.takeException(), isNull);
  });

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
