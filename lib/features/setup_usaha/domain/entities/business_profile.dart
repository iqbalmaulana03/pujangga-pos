class BusinessProfile {
  const BusinessProfile({
    required this.businessName,
    required this.businessType,
    this.address,
    this.contactNumber,
    this.ownerName,
    this.logoPath,
    this.modalAwalUsaha,
  });

  final String businessName;
  final String businessType;
  final String? address;
  final String? contactNumber;
  final String? ownerName;
  final String? logoPath;
  final double? modalAwalUsaha;

  BusinessProfile copyWith({
    String? businessName,
    String? businessType,
    String? address,
    String? contactNumber,
    String? ownerName,
    String? logoPath,
    double? modalAwalUsaha,
  }) {
    return BusinessProfile(
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      address: address ?? this.address,
      contactNumber: contactNumber ?? this.contactNumber,
      ownerName: ownerName ?? this.ownerName,
      logoPath: logoPath ?? this.logoPath,
      modalAwalUsaha: modalAwalUsaha ?? this.modalAwalUsaha,
    );
  }
}
