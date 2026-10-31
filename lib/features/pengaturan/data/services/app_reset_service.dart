import 'package:logging/logging.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/business_logo_service.dart';

class AppResetService {
  const AppResetService({
    required this.database,
    required this.logger,
    this.logoService,
  });

  final AppDatabase database;
  final Logger logger;
  final BusinessLogoService? logoService;

  Future<void> resetAppData() =>
      (logoService ?? BusinessLogoService()).synchronized(() async {
        logger.warning('Resetting all local application data');
        final db = await database.database();
        final profiles = await db.query(
          'business_profile',
          columns: ['logo_path'],
        );
        await database.reset();
        final logos = logoService ?? BusinessLogoService();
        for (final profile in profiles) {
          await logos.deleteOwned(profile['logo_path'] as String?);
        }
      });
}
