import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/datasources/app_settings_local_data_source.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

final appSettingsLocalDataSourceProvider = Provider<AppSettingsLocalDataSource>(
  (ref) {
    return AppSettingsLocalDataSource(database: ref.watch(appDatabaseProvider));
  },
);

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(
    localDataSource: ref.watch(appSettingsLocalDataSourceProvider),
  );
});

final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final settings = await ref.watch(settingsRepositoryProvider).getSettings();
  final resolved =
      settings ??
      const AppSettings(
        currencyCode: 'IDR',
        currencySymbol: 'Rp',
        defaultTaxPercent: 0,
        stockAllowNegative: false,
        autoPrintReceipt: true,
      );
  CurrencyFormatter.configure(
    currencyCode: resolved.currencyCode,
    currencySymbol: resolved.currencySymbol,
  );
  return resolved;
});

final pengaturanSettingsControllerProvider =
    AsyncNotifierProvider<PengaturanSettingsController, void>(
      PengaturanSettingsController.new,
    );

class PengaturanSettingsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save(AppSettings settings) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(settingsRepositoryProvider).saveSettings(settings);
      CurrencyFormatter.configure(
        currencyCode: settings.currencyCode,
        currencySymbol: settings.currencySymbol,
      );
      ref.invalidate(appSettingsProvider);
    });
  }
}
