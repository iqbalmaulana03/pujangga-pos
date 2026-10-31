import 'package:flutter/foundation.dart';

/// Serializes native camera operations, including disposal during startup.
class ScannerSession {
  ScannerSession({
    required this.start,
    required this.stop,
    required this.dispose,
  });

  final AsyncCallback start;
  final AsyncCallback stop;
  final AsyncCallback dispose;
  Future<void> _pending = Future.value();
  bool _active = false;
  bool _closed = false;

  Future<void> setActive(bool active) {
    if (_closed) return _pending;
    _active = active;
    return _enqueue(() async {
      if (_closed || !_active) {
        await stop();
      } else {
        await start();
      }
    });
  }

  Future<void> close() {
    if (_closed) return _pending;
    _closed = true;
    return _enqueue(() async {
      try {
        await stop();
      } finally {
        await dispose();
      }
    });
  }

  Future<void> _enqueue(AsyncCallback operation) {
    _pending = _pending.then((_) => operation()).catchError((Object error) {
      // The scanner controller exposes start/permission failures in its value.
      // A failed operation must not prevent a subsequent stop/dispose.
      debugPrint('Scanner session operation failed: ${error.runtimeType}');
    });
    return _pending;
  }
}
