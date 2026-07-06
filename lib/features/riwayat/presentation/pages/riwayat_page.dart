import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/placeholder_feature_screen.dart';

class RiwayatPage extends StatelessWidget {
  const RiwayatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: PlaceholderFeatureScreen(
        badge: 'Screen Canonical: Riwayat Transaksi',
        title:
            'Subflow riwayat transaksi sudah terhubung dari beranda dan transaksi.',
        description:
            'Halaman ini berdiri di luar bottom navigation untuk mengikuti aturan navigasi final pada dokumen canonical.',
        highlights: const [
          'Route /history tersedia untuk daftar transaksi.',
          'Route /history/:id tersedia untuk detail transaksi.',
          'Posisi flow mengikuti aturan final: bukan tab utama.',
        ],
        primaryAction: FilledButton.icon(
          onPressed: () => context.push('/history/INV-0001'),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Buka Detail Contoh'),
        ),
      ),
    );
  }
}
