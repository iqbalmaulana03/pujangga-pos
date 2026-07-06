import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../features/setup_usaha/data/datasources/business_profile_local_data_source.dart';
import '../../features/setup_usaha/data/repositories/business_profile_repository_impl.dart';
import '../../features/setup_usaha/domain/repositories/business_profile_repository.dart';
import '../database/app_database.dart';
import 'app_logger.dart';

final appLoggerProvider = Provider<Logger>((ref) {
  return AppLogger.bootstrap();
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase(logger: ref.watch(appLoggerProvider));
});

final businessProfileLocalDataSourceProvider =
    Provider<BusinessProfileLocalDataSource>((ref) {
      return BusinessProfileLocalDataSource(
        database: ref.watch(appDatabaseProvider),
      );
    });

final businessProfileRepositoryProvider = Provider<BusinessProfileRepository>((
  ref,
) {
  return BusinessProfileRepositoryImpl(
    localDataSource: ref.watch(businessProfileLocalDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final appStartupServiceProvider = Provider<AppStartupService>((ref) {
  return AppStartupService(
    database: ref.watch(appDatabaseProvider),
    businessProfileRepository: ref.watch(businessProfileRepositoryProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final appStartupProvider = FutureProvider<AppStartupState>((ref) async {
  return ref.watch(appStartupServiceProvider).load();
});

class AppStartupState {
  const AppStartupState({required this.hasBusinessProfile});

  final bool hasBusinessProfile;
}

class AppStartupService {
  const AppStartupService({
    required this.database,
    required this.businessProfileRepository,
    required this.logger,
  });

  final AppDatabase database;
  final BusinessProfileRepository businessProfileRepository;
  final Logger logger;

  Future<AppStartupState> load() async {
    logger.info('App init started');
    await database.database();
    logger.info('Database init completed');

    final hasBusinessProfile = await businessProfileRepository.hasProfile();
    logger.info('Business profile exists: $hasBusinessProfile');

    return AppStartupState(hasBusinessProfile: hasBusinessProfile);
  }
}
