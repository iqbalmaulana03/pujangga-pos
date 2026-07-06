import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../shared/widgets/placeholder_feature_screen.dart';

class KatalogPage extends StatelessWidget {
  const KatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderFeatureScreen(
      badge: 'Screen Canonical: Katalog',
      title: 'Daftar barang dan jasa siap dijadikan entry point transaksi.',
      description:
          'Struktur feature-first untuk katalog sudah disiapkan agar issue berikutnya bisa langsung menambahkan list, filter, form, dan repository SQLite.',
      highlights: const [
        'Route /catalog sudah aktif di bottom navigation utama.',
        'Route /catalog/create dan /catalog/edit/:id sudah tersedia untuk form item.',
        'Boundary layer presentation, domain, dan data sudah dipisahkan sejak awal.',
      ],
      primaryAction: FilledButton.icon(
        onPressed: () => context.push(AppRoutes.catalogCreate),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Item'),
      ),
    );
  }
}
