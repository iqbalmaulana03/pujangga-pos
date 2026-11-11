import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/app_recovery_service.dart';
import 'pengaturan_backup_controller.dart';
import 'pengaturan_reset_controller.dart';
import 'pengaturan_restore_controller.dart';

final appRecoveryServiceProvider = Provider<AppRecoveryService>((ref) {
  return AppRecoveryService(
    backup: ref.watch(appBackupServiceProvider),
    restore: ref.watch(appRestoreServiceProvider),
    reset: ref.watch(appResetServiceProvider),
  );
});

final recoverySnapshotsProvider = FutureProvider.autoDispose<List<File>>((ref) {
  return ref.watch(appRecoveryServiceProvider).snapshots();
});
