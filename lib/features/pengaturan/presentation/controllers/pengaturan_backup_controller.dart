import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../data/services/app_backup_service.dart';
import '../../domain/entities/app_backup_file.dart';

final appBackupServiceProvider = Provider<AppBackupService>((ref) {
  return AppBackupService(
    database: ref.watch(appDatabaseProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

final pengaturanBackupControllerProvider =
    AsyncNotifierProvider<PengaturanBackupController, AppBackupFile?>(
      PengaturanBackupController.new,
    );

class PengaturanBackupController extends AsyncNotifier<AppBackupFile?> {
  @override
  Future<AppBackupFile?> build() async => null;

  Future<AppBackupFile> createBackup() async {
    state = const AsyncLoading();

    try {
      final backup = await ref.read(appBackupServiceProvider).createBackup();
      state = AsyncData(backup);
      return backup;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
