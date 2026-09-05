enum ReportPeriod { harian, mingguan, bulanan, tahunan, kustom }

class ReportRange {
  const ReportRange({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;
}

extension ReportPeriodX on ReportPeriod {
  String get label {
    switch (this) {
      case ReportPeriod.harian:
        return 'Harian';
      case ReportPeriod.mingguan:
        return 'Mingguan';
      case ReportPeriod.bulanan:
        return 'Bulanan';
      case ReportPeriod.tahunan:
        return 'Tahunan';
      case ReportPeriod.kustom:
        return 'Kustom';
    }
  }

  String get description {
    switch (this) {
      case ReportPeriod.harian:
        return 'Ringkasan omzet dan transaksi hari ini.';
      case ReportPeriod.mingguan:
        return 'Performa penjualan 7 hari berjalan.';
      case ReportPeriod.bulanan:
        return 'Ringkasan penjualan untuk bulan berjalan.';
      case ReportPeriod.tahunan:
        return 'Ringkasan penjualan untuk tahun berjalan.';
      case ReportPeriod.kustom:
        return 'Ringkasan penjualan pada rentang waktu yang dipilih.';
    }
  }

  ReportRange resolveRange([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case ReportPeriod.harian:
        return ReportRange(
          start: today,
          endExclusive: today.add(const Duration(days: 1)),
        );
      case ReportPeriod.mingguan:
        final start = today.subtract(Duration(days: today.weekday - 1));
        return ReportRange(
          start: start,
          endExclusive: start.add(const Duration(days: 7)),
        );
      case ReportPeriod.bulanan:
        final start = DateTime(now.year, now.month);
        return ReportRange(
          start: start,
          endExclusive: DateTime(now.year, now.month + 1),
        );
      case ReportPeriod.tahunan:
        final start = DateTime(now.year);
        return ReportRange(
          start: start,
          endExclusive: DateTime(now.year + 1),
        );
      case ReportPeriod.kustom:
        return ReportRange(
          start: today,
          endExclusive: today.add(const Duration(days: 1)),
        );
    }
  }
}
