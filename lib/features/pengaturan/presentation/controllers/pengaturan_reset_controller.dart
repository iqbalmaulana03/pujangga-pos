import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../data/services/app_reset_service.dart';
import 'pengaturan_backup_controller.dart';
import 'pengaturan_settings_controller.dart';

final appResetServiceProvider = Provider<AppResetService>((ref) {
  return AppResetService(
    database: ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
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
    state = await AsyncValue.guard(() async {
      await ref.read(appResetServiceProvider).resetAppData();

      ref.invalidate(appStartupProvider);
      ref.invalidate(businessProfileProvider);
      ref.invalidate(appSettingsProvider);
      ref.invalidate(pengaturanBackupControllerProvider);
    });
  }
}
