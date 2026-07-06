import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../../setup_usaha/domain/entities/business_profile.dart';

final pengaturanProfilControllerProvider =
    AsyncNotifierProvider<PengaturanProfilController, void>(
      PengaturanProfilController.new,
    );

class PengaturanProfilController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save(BusinessProfile businessProfile) async {
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

      ref.invalidate(appStartupProvider);
      ref.invalidate(businessProfileProvider);
    });
  }
}
