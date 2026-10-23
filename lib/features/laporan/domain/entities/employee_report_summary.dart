class EmployeeReportSummary {
  const EmployeeReportSummary({
    required this.employeeId,
    required this.employeeName,
    required this.revenue,
    required this.transactionCount,
    required this.compensation,
    required this.expense,
  });
  final int employeeId;
  final String employeeName;
  final double revenue;
  final int transactionCount;
  final double compensation;
  final double expense;
}
