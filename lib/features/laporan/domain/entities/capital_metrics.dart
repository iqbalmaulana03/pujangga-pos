class CapitalMetrics {
  const CapitalMetrics({
    required this.initialCapital,
    required this.currentCash,
    required this.currentStockValue,
    this.historicalCapitals = const [],
  });

  final double initialCapital;
  final double currentCash;
  final double currentStockValue;
  final List<double> historicalCapitals;

  double get netCapitalValue => currentCash + currentStockValue;

  double get roiPercentage {
    if (initialCapital <= 0) {
      return 0.0;
    }
    return ((netCapitalValue - initialCapital) / initialCapital) * 100;
  }
}
