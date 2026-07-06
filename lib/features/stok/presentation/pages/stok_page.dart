import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../shared/widgets/placeholder_feature_screen.dart';

class StokPage extends StatelessWidget {
  const StokPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderFeatureScreen(
      badge: 'Screen Canonical: Manajemen Stok',
      title:
          'Ringkasan stok dan entry point penyesuaian manual sudah tersedia.',
      description:
          'Route stok mengikuti canonical set dan menyiapkan jalur untuk detail item serta histori penyesuaian stok pada issue berikutnya.',
      highlights: const [
        'Route /stock aktif di bottom navigation.',
        'Route /stock/:itemId aktif untuk detail stok item.',
        'Issue transaksi berikutnya bisa menghubungkan pengurangan stok otomatis ke repository stok.',
      ],
      primaryAction: FilledButton.icon(
        onPressed: () => context.push('${AppRoutes.stock}/kopi-arabika'),
        icon: const Icon(Icons.tune),
        label: const Text('Buka Detail Stok'),
      ),
    );
  }
}
