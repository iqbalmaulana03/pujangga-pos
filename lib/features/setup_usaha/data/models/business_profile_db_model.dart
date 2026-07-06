import '../../domain/entities/business_profile.dart';

class BusinessProfileDbModel {
  const BusinessProfileDbModel({
    required this.id,
    required this.businessName,
    required this.businessType,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String businessName;
  final String businessType;
  final String createdAt;
  final String updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'business_name': businessName,
      'business_type': businessType,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory BusinessProfileDbModel.fromEntity(BusinessProfile profile) {
    final timestamp = DateTime.now().toIso8601String();
    return BusinessProfileDbModel(
      id: 1,
      businessName: profile.businessName,
      businessType: profile.businessType,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}
