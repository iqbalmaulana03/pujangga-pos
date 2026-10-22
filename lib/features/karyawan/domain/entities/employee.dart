class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.isActive,
    required this.compensationType,
    this.commissionPercent,
    this.commissionScope = 'all',
    this.monthlySalary,
    required this.effectiveFrom,
    this.notes,
  });

  final int id;
  final String name;
  final bool isActive;
  final String compensationType;
  final double? commissionPercent;
  final String commissionScope;
  String get commissionScopeLabel => switch (commissionScope) {
    'service' => 'Jasa saja',
    'product' => 'Barang saja',
    _ => 'Barang dan jasa',
  };
  final double? monthlySalary;
  final DateTime effectiveFrom;
  final String? notes;

  bool get isCommission => compensationType == 'commission';
}
