import '../../domain/entities/business_profile.dart';

class BusinessProfileDbModel {
  const BusinessProfileDbModel({
    required this.id,
    required this.businessName,
    required this.businessType,
    this.address,
    this.contactNumber,
    this.ownerName,
    this.logoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String businessName;
  final String businessType;
  final String? address;
  final String? contactNumber;
  final String? ownerName;
  final String? logoPath;
  final String createdAt;
  final String updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'business_name': businessName,
      'business_type': businessType,
      'address': address,
      'phone': contactNumber,
      'owner_name': ownerName,
      'logo_path': logoPath,
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
      address: profile.address,
      contactNumber: profile.contactNumber,
      ownerName: profile.ownerName,
      logoPath: null,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory BusinessProfileDbModel.fromMap(Map<String, Object?> map) {
    return BusinessProfileDbModel(
      id: (map['id'] as num).toInt(),
      businessName: map['business_name'] as String,
      businessType: map['business_type'] as String,
      address: map['address'] as String?,
      contactNumber: map['phone'] as String?,
      ownerName: map['owner_name'] as String?,
      logoPath: map['logo_path'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  BusinessProfile toEntity() {
    return BusinessProfile(
      businessName: businessName,
      businessType: businessType,
      address: address,
      contactNumber: contactNumber,
      ownerName: ownerName,
    );
  }
}
