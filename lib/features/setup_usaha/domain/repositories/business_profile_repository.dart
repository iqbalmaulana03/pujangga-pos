import '../entities/business_profile.dart';

abstract class BusinessProfileRepository {
  Future<bool> hasProfile();
  Future<BusinessProfile?> getProfile();
  Future<void> saveProfile(BusinessProfile profile);
}
