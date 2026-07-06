import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/models/quick_action.dart';

class BerandaPage extends StatelessWidget {
  const BerandaPage({super.key});

  @override
  Widget build(BuildContext context) {
    const quickActions = [
      QuickAction(
        label: 'Tambah Item',
        icon: Icons.add_box_outlined,
        route: AppRoutes.catalogCreate,
      ),
      QuickAction(
        label: 'Buat Transaksi',
        icon: Icons.point_of_sale_outlined,
        route: AppRoutes.transaction,
      ),
      QuickAction(
        label: 'Riwayat',
        icon: Icons.receipt_long_outlined,
        route: AppRoutes.history,
      ),
      QuickAction(
        label: 'Pengaturan',
        icon: Icons.settings_outlined,
        route: AppRoutes.settings,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9C4F1A), Color(0xFFC56E33)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warm Operational Minimalism',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'Beranda Pujangga POS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Placeholder ini mengikuti canonical flow MVP: ringkasan bisnis, shortcut ke transaksi, katalog, stok, dan laporan.',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Omzet Hari Ini',
                value: CurrencyFormatter.format(275000),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _SummaryCard(label: 'Transaksi Hari Ini', value: '12'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: _SummaryCard(
                label: 'Item Terlaris',
                value: 'Es Kopi Susu',
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _SummaryCard(label: 'Metode Top', value: 'QRIS'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Shortcut Operasional',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in quickActions)
              SizedBox(
                width: 160,
                child: FilledButton.tonalIcon(
                  onPressed: () => context.push(action.route),
                  icon: Icon(action.icon),
                  label: Text(action.label),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
