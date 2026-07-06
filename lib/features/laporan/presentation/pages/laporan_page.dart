import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_feature_screen.dart';

class LaporanPage extends StatelessWidget {
  const LaporanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderFeatureScreen(
      badge: 'Screen Canonical: Laporan',
      title: 'Fondasi laporan operasional sudah siap untuk agregasi SQLite.',
      description:
          'Issue ini menyiapkan route dan shell utama agar dashboard serta laporan bisa dikembangkan di atas repository aggregation query tanpa menyentuh UI secara langsung.',
      highlights: [
        'Route /reports aktif di bottom navigation utama.',
        'Layer repository terpisah untuk query agregasi omzet dan item terlaris.',
        'Flow laporan tetap local-first dan mengikuti batasan MVP tanpa backend.',
      ],
    );
  }
}
