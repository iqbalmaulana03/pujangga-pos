import '../entities/business_profile.dart';

abstract class BusinessProfileRepository {
  Future<bool> hasProfile();
  Future<void> saveProfile(BusinessProfile profile);
}
