import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scanner_session.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key, this.onReleased});

  final VoidCallback? onReleased;

  static Future<String?> scan(BuildContext context) async {
    final released = Completer<void>();
    final route = MaterialPageRoute<String>(
      builder: (_) => BarcodeScannerPage(onReleased: released.complete),
    );
    // Stock and transaction pages live inside StatefulShellRoute branch
    // navigators, while dialogs opened after scanning use the root navigator.
    // Keep the scanner on that same root overlay so its camera route is fully
    // removed before the caller opens a dialog or updates the branch page.
    final navigator = Navigator.of(context, rootNavigator: true);
    final barcode = await navigator.push<String>(route);

    // The popped future resolves before the reverse transition removes the
    // scanner route. Wait until its overlay is gone before callers open a
    // dialog or update route-dependent widgets.
    await route.completed;
    await released.future;
    return barcode;
  }

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _didRead = false;
  late final ScannerSession _session;

  @override
  void initState() {
    super.initState();
    _session = ScannerSession(
      start: () => _controller.start(),
      stop: () => _controller.stop(),
      dispose: () => _controller.dispose(),
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          _session.setActive(
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
          ),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      _session.setActive(state == AppLifecycleState.resumed && !_didRead),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final onReleased = widget.onReleased;
    unawaited(_session.close().whenComplete(() => onReleased?.call()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindai Barcode'),
        actions: [
          IconButton(
            tooltip: 'Nyalakan atau matikan lampu',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_outlined),
          ),
          IconButton(
            tooltip: 'Ganti kamera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_didRead) return;
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue?.trim();
                if (value == null || value.isEmpty) continue;
                _didRead = true;
                unawaited(_session.setActive(false));
                Navigator.of(context).pop(value);
                break;
              }
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: MediaQuery.sizeOf(context).width * 0.78,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Arahkan garis di tengah ke barcode produk.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
