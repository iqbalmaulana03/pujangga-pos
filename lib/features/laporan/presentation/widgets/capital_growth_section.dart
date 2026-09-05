import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../controllers/laporan_controller.dart';

class CapitalGrowthSection extends ConsumerWidget {
  const CapitalGrowthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capitalAsync = ref.watch(capitalMetricsProvider);

    return capitalAsync.when(
      data: (metrics) {
        final roi = metrics.roiPercentage;
        final isPositive = roi >= 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ROI Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBEC9C6).withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Return on Capital (ROI)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3F4947),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositive ? const Color(0xFFDDEEE7) : const Color(0xFFFFDAD6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive ? Icons.trending_up : Icons.trending_down,
                              size: 14,
                              color: isPositive ? const Color(0xFF0D5C56) : const Color(0xFFBA1A1A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${roi.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPositive ? const Color(0xFF0D5C56) : const Color(0xFFBA1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    CurrencyFormatter.format(metrics.netCapitalValue - metrics.initialCapital),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF191C1C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Laba Bersih Berjalan',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF3F4947),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Total Kapital (Kas+Stok): ${CurrencyFormatter.format(metrics.netCapitalValue)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3F4947),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Growth Chart
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBEC9C6).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pertumbuhan Kapital',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF191C1C),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 180,
                    child: Builder(
                      builder: (context) {
                        double maxY = metrics.netCapitalValue;
                        for (final cap in metrics.historicalCapitals) {
                          if (cap > maxY) maxY = cap;
                        }
                        
                        final groups = <BarChartGroupData>[];
                        for (int i = 0; i < metrics.historicalCapitals.length; i++) {
                          final cap = metrics.historicalCapitals[i];
                          groups.add(
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: cap,
                                  color: const Color(0xFFBEC9C6),
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        groups.add(
                          BarChartGroupData(
                            x: metrics.historicalCapitals.length,
                            barRods: [
                              BarChartRodData(
                                toY: metrics.netCapitalValue,
                                color: isPositive ? const Color(0xFF0D5C56) : const Color(0xFFBA1A1A),
                                width: 20,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          ),
                        );

                        return BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxY * 1.2,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => const Color(0xFF191C1C),
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    CurrencyFormatter.format(rod.toY),
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    String text = '';
                                    if (index == 0 && metrics.historicalCapitals.length == 1) {
                                      text = 'Modal';
                                    } else if (index == 0) {
                                      text = 'Awal';
                                    } else if (index == metrics.historicalCapitals.length) {
                                      text = 'Skrg';
                                    } else {
                                      text = 'H-$index';
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        text,
                                        style: const TextStyle(
                                          color: Color(0xFF3F4947),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    );
                                  },
                                  reservedSize: 28,
                                ),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: const Color(0xFFECEEED),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: groups,
                          ),
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      )),
      error: (error, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFDAD6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Gagal memuat metrik kapital: $error',
          style: const TextStyle(color: Color(0xFFBA1A1A)),
        ),
      ),
    );
  }
}
