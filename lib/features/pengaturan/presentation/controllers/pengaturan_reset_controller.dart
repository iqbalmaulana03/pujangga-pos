import '../../../../core/services/business_logo_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../../../core/services/dataset_generation.dart';
import '../../data/services/app_reset_service.dart';
import 'pengaturan_backup_controller.dart';
import 'app_recovery_provider.dart';

final appResetServiceProvider = Provider<AppResetService>((ref) {
  return AppResetService(
    database: ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
    logoService: ref.watch(businessLogoServiceProvider),
  );
});

final pengaturanResetControllerProvider =
    AsyncNotifierProvider<PengaturanResetController, void>(
      PengaturanResetController.new,
    );

class PengaturanResetController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> resetAppData() async {
    state = const AsyncLoading();
    try {
      await ref.read(appRecoveryServiceProvider).resetAndDeleteLocalBackups();

      ref.read(datasetGenerationProvider.notifier).advance();
      ref.invalidate(pengaturanBackupControllerProvider);
      ref.invalidate(recoverySnapshotsProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
