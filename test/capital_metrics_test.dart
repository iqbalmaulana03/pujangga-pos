import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/capital_metrics.dart';

void main() {
  group('CapitalMetrics', () {
    test('should calculate netCapitalValue correctly', () {
      const metrics = CapitalMetrics(
        initialCapital: 1000000,
        currentCash: 1200000,
        currentStockValue: 300000,
      );

      expect(metrics.netCapitalValue, 1500000);
    });

    test('should calculate roiPercentage correctly when positive', () {
      const metrics = CapitalMetrics(
        initialCapital: 1000000,
        currentCash: 900000,
        currentStockValue: 250000,
      );
      // Net Capital = 1,150,000
      // ROI = (1,150,000 - 1,000,000) / 1,000,000 * 100 = 15%

      expect(metrics.roiPercentage, 15.0);
    });

    test('should calculate roiPercentage correctly when negative', () {
      const metrics = CapitalMetrics(
        initialCapital: 1000000,
        currentCash: 500000,
        currentStockValue: 400000,
      );
      // Net Capital = 900,000
      // ROI = (900,000 - 1,000,000) / 1,000,000 * 100 = -10%

      expect(metrics.roiPercentage, -10.0);
    });

    test('should return 0 ROI if initialCapital is 0', () {
      const metrics = CapitalMetrics(
        initialCapital: 0,
        currentCash: 100000,
        currentStockValue: 50000,
      );

      expect(metrics.roiPercentage, 0.0);
    });
  });
}
