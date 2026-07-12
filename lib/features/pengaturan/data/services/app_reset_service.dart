import 'package:logging/logging.dart';

import '../../../../core/database/app_database.dart';

class AppResetService {
  const AppResetService({required this.database, required this.logger});

  final AppDatabase database;
  final Logger logger;

  Future<void> resetAppData() async {
    logger.warning('Resetting all local application data');
    await database.reset();
  }
}
