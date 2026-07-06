import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../shared/widgets/placeholder_feature_screen.dart';

class TransaksiPage extends StatelessWidget {
  const TransaksiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderFeatureScreen(
      badge: 'Screen Canonical: Transaksi Baru',
      title:
          'Checkout placeholder dengan jalur pengembangan jelas untuk cart dan pembayaran.',
      description:
          'Issue ini belum mengimplementasikan logic cart, tetapi route inti, shell navigasi, dan fondasi repository SQLite sudah siap untuk modul transaksi.',
      highlights: const [
        'Route /transaction aktif sebagai tab operasional utama.',
        'Riwayat transaksi diakses sebagai subflow, bukan tab utama.',
        'Arsitektur sudah menegaskan transaksi dan update stok harus berjalan dalam database transaction.',
      ],
      primaryAction: FilledButton.icon(
        onPressed: () => context.push(AppRoutes.history),
        icon: const Icon(Icons.receipt_long_outlined),
        label: const Text('Lihat Riwayat'),
      ),
    );
  }
}
