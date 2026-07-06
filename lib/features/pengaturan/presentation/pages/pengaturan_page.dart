import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_feature_screen.dart';

class PengaturanPage extends StatelessWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: PlaceholderFeatureScreen(
          badge: 'Screen Canonical: Pengaturan',
          title:
              'Pengaturan berdiri sebagai subflow local-first, bukan tab utama.',
          description:
              'Halaman ini mengikuti keputusan canonical bahwa pengaturan memuat profil usaha, preferensi operasional, dan nantinya pengelolaan data lokal.',
          highlights: [
            'Route /settings aktif di luar bottom navigation.',
            'Issue berikutnya dapat menambahkan profil usaha, mata uang, dan pengaturan struk.',
            'Struktur folder sudah siap untuk repository settings berbasis SQLite.',
          ],
        ),
      ),
    );
  }
}
