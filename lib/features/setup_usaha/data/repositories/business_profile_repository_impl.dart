import 'package:logging/logging.dart';

import 'dart:io';

import '../../../../core/services/business_logo_service.dart';
import '../../../../core/errors/app_exception.dart';

import '../../domain/entities/business_profile.dart';
import '../../domain/repositories/business_profile_repository.dart';
import '../datasources/business_profile_local_data_source.dart';
import '../models/business_profile_db_model.dart';

class BusinessProfileRepositoryImpl implements BusinessProfileRepository {
  const BusinessProfileRepositoryImpl({
    required this.localDataSource,
    required this.logger,
    this.logoService,
  });

  final BusinessProfileLocalDataSource localDataSource;
  final Logger logger;
  final BusinessLogoService? logoService;

  @override
  Future<bool> hasProfile() async {
    return localDataSource.hasProfile();
  }

  @override
  Future<BusinessProfile?> getProfile() async {
    final profile = await localDataSource.getProfile();
    return profile?.toEntity();
  }

  @override
  Future<void> saveProfile(BusinessProfile profile) async {
    final logos = logoService ?? BusinessLogoService();
    await logos.synchronized(() async {
      final old = await getProfile();
      var saved = profile;
      String? created;
      final source = profile.logoPath;
      if (source != null && source.isNotEmpty) {
        try {
          if (!await logos.owns(source)) {
            final bytes = await logos.normalize(await logos.readSource(source));
            created = await logos.write(bytes);
            saved = profile.copyWith(logoPath: created);
          }
        } on FileSystemException {
          if (old?.logoPath != source) rethrow;
        } on AppException {
          if (old?.logoPath != source) rethrow;
        }
      }
      try {
        await localDataSource.saveProfile(
          BusinessProfileDbModel.fromEntity(saved),
        );
      } catch (_) {
        await logos.deleteOwned(created);
        rethrow;
      }
      if (old?.logoPath != saved.logoPath) {
        await logos.deleteOwned(old?.logoPath);
      }
    });
  }
}
