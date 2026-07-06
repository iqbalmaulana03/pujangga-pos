import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../domain/entities/business_profile.dart';

final setupUsahaControllerProvider =
    AsyncNotifierProvider<SetupUsahaController, void>(SetupUsahaController.new);

class SetupUsahaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String businessName,
    required String businessType,
  }) async {
    if (businessName.trim().isEmpty || businessType.trim().isEmpty) {
      throw const AppException(
        'validation_error',
        'Nama usaha dan jenis usaha wajib diisi.',
      );
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(businessProfileRepositoryProvider)
          .saveProfile(
            BusinessProfile(
              businessName: businessName.trim(),
              businessType: businessType.trim(),
            ),
          );

      ref.invalidate(appStartupProvider);
    });
  }
}
