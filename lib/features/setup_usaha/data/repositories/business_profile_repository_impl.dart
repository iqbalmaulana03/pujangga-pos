import 'package:logging/logging.dart';

import '../../domain/entities/business_profile.dart';
import '../../domain/repositories/business_profile_repository.dart';
import '../datasources/business_profile_local_data_source.dart';
import '../models/business_profile_db_model.dart';

class BusinessProfileRepositoryImpl implements BusinessProfileRepository {
  const BusinessProfileRepositoryImpl({
    required this.localDataSource,
    required this.logger,
  });

  final BusinessProfileLocalDataSource localDataSource;
  final Logger logger;

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
    logger.info('Saving business profile for ${profile.businessName}');
    await localDataSource.saveProfile(
      BusinessProfileDbModel.fromEntity(profile),
    );
  }
}
