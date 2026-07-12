import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../data/services/app_restore_service.dart';
import '../../data/services/backup_file_picker_service.dart';
import '../../domain/entities/app_backup_restore_candidate.dart';
import 'pengaturan_backup_controller.dart';
import 'pengaturan_reset_controller.dart';
import 'pengaturan_settings_controller.dart';

final backupFilePickerServiceProvider = Provider<BackupFilePickerService>((
  ref,
) {
  return const BackupFilePickerService();
});

final appRestoreServiceProvider = Provider<AppRestoreService>((ref) {
  return AppRestoreService(
    database: ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final pengaturanRestoreControllerProvider =
    AsyncNotifierProvider<
      PengaturanRestoreController,
      AppBackupRestoreCandidate?
    >(PengaturanRestoreController.new);

class PengaturanRestoreController
    extends AsyncNotifier<AppBackupRestoreCandidate?> {
  @override
  Future<AppBackupRestoreCandidate?> build() async => null;

  Future<AppBackupRestoreCandidate?> pickBackupFile() async {
    state = const AsyncLoading();

    try {
      final path = await ref
          .read(backupFilePickerServiceProvider)
          .pickBackupFile();
      if (path == null) {
        state = const AsyncData(null);
        return null;
      }

      final candidate = await ref
          .read(appRestoreServiceProvider)
          .inspectBackupFile(path);
      state = AsyncData(candidate);
      return candidate;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> restoreBackup(AppBackupRestoreCandidate candidate) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await ref.read(appRestoreServiceProvider).restoreBackup(candidate);

      ref.invalidate(appStartupProvider);
      ref.invalidate(businessProfileProvider);
      ref.invalidate(appSettingsProvider);
      ref.invalidate(pengaturanBackupControllerProvider);
      ref.invalidate(pengaturanResetControllerProvider);
      return candidate;
    });
  }
}
