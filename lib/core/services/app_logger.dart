import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

class AppLogger {
  AppLogger._();

  static Logger bootstrap() {
    Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
    Logger.root.onRecord.listen((record) {
      debugPrint(
        '[${record.loggerName}] ${record.level.name}: ${record.time.toIso8601String()} ${record.message}',
      );
    });

    return Logger('PujanggaPOS');
  }
}
