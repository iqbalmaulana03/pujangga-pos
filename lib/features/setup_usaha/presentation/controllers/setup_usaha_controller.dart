import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../../pengaturan/domain/entities/app_settings.dart';
import '../../../pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import '../../domain/entities/business_profile.dart';

final setupUsahaControllerProvider =
    AsyncNotifierProvider<SetupUsahaController, void>(SetupUsahaController.new);

class SetupUsahaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required BusinessProfile businessProfile,
    String? currencyCode,
  }) async {
    if (businessProfile.businessName.trim().isEmpty ||
        businessProfile.businessType.trim().isEmpty) {
      throw const AppException(
        'validation_error',
        'Nama usaha dan jenis usaha wajib diisi.',
      );
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(businessProfileRepositoryProvider)
          .saveProfile(businessProfile);

      if (currencyCode != null) {
        String symbol = 'Rp';
        if (currencyCode == 'USD') {
          symbol = r'$';
        } else if (currencyCode == 'SGD') {
          symbol = r'S$';
        }

        final settingsRepository = ref.read(settingsRepositoryProvider);
        final existingSettings = await settingsRepository.getSettings();
        final newSettings = AppSettings(
          currencyCode: currencyCode,
          currencySymbol: symbol,
          defaultTaxPercent: existingSettings?.defaultTaxPercent ?? 0.0,
          stockAllowNegative: existingSettings?.stockAllowNegative ?? false,
          receiptHeader: existingSettings?.receiptHeader,
          receiptFooter: existingSettings?.receiptFooter,
        );
        await settingsRepository.saveSettings(newSettings);
        ref.invalidate(appSettingsProvider);
      }

      ref.invalidate(appStartupProvider);
      ref.invalidate(businessProfileProvider);
    });
  }
}
