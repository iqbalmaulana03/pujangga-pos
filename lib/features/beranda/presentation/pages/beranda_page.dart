import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/models/quick_action.dart';
import '../../../laporan/presentation/controllers/laporan_controller.dart';

class BerandaPage extends ConsumerWidget {
  const BerandaPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(businessProfileProvider);
    ref.invalidate(dashboardSummaryProvider);

    await Future.wait([
      ref.read(businessProfileProvider.future),
      ref.read(dashboardSummaryProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfileProvider);
    final dashboardAsync = ref.watch(dashboardSummaryProvider);

    return dashboardAsync.when(
      data: (summary) {
        final profile = profileAsync.asData?.value;
        final now = DateTime.now();
        final dateLabel = _formatFullDate(now);
        final quickActions = [
          const QuickAction(
            label: 'Buat Transaksi',
            icon: Icons.point_of_sale_outlined,
            route: AppRoutes.transaction,
          ),
          const QuickAction(
            label: 'Tambah Item',
            icon: Icons.add_box_outlined,
            route: AppRoutes.catalogCreate,
          ),
          const QuickAction(
            label: 'Lihat Laporan',
            icon: Icons.bar_chart_outlined,
            route: AppRoutes.reports,
          ),
          const QuickAction(
            label: 'Riwayat',
            icon: Icons.receipt_long_outlined,
            route: AppRoutes.history,
          ),
        ];

        return RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF11564F), Color(0xFF34716A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'RINGKASAN HARI INI',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      profile?.businessName ?? 'Beranda Pujangga POS',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile == null
                          ? dateLabel
                          : '${profile.businessType} • $dateLabel',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFE0EFE8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF11564F),
                            ),
                            onPressed: () => context.push(AppRoutes.transaction),
                            child: const Text('Buat Transaksi'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                            ),
                            onPressed: () => context.push(AppRoutes.catalogCreate),
                            child: const Text('Tambah Item'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.28,
                children: [
                  _MetricCard(
                    label: 'Omzet Hari Ini',
                    value: CurrencyFormatter.format(summary.revenueToday),
                    icon: Icons.payments_outlined,
                    accent: const Color(0xFF11564F),
                  ),
                  _MetricCard(
                    label: 'Transaksi Hari Ini',
                    value: '${summary.transactionCountToday}',
                    icon: Icons.receipt_long_outlined,
                    accent: const Color(0xFF9C4F1A),
                  ),
                  _MetricCard(
                    label: 'Item Terlaris',
                    value: summary.topItemName ?? 'Belum ada',
                    icon: Icons.local_fire_department_outlined,
                    accent: const Color(0xFF6B4A8B),
                    supporting: summary.topItemName == null
                        ? 'Mulai transaksi pertama'
                        : '${summary.topItemQuantity.toStringAsFixed(0)} terjual',
                  ),
                  _MetricCard(
                    label: 'Metode Top',
                    value: summary.topPaymentMethod ?? 'Belum ada',
                    icon: Icons.qr_code_2_outlined,
                    accent: const Color(0xFF4A6A3C),
                    supporting: summary.hasTransactions
                        ? 'Paling sering dipakai'
                        : 'Data muncul setelah transaksi',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fokus Operasional',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary.hasTransactions
                            ? 'Hari ini ${profile?.businessName ?? 'usaha Anda'} sudah mencatat ${summary.transactionCountToday} transaksi dengan omzet ${CurrencyFormatter.format(summary.revenueToday)}.'
                            : 'Belum ada transaksi hari ini. Gunakan shortcut di bawah untuk mulai operasional dan isi data laporan pertama.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            _FocusRow(
                              label: 'Item paling laku',
                              value: summary.topItemName ?? 'Belum ada data',
                            ),
                            const SizedBox(height: 10),
                            _FocusRow(
                              label: 'Pembayaran dominan',
                              value:
                                  summary.topPaymentMethod ?? 'Belum ada data',
                            ),
                            const SizedBox(height: 10),
                            _FocusRow(
                              label: 'Akses laporan',
                              value: 'Buka tab Laporan untuk rekap lengkap',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                    _QuickActionCard(action: action),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Gagal memuat dashboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(dashboardSummaryProvider),
                  child: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.supporting,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? supporting;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const Spacer(),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (supporting != null) ...[
              const SizedBox(height: 6),
              Text(
                supporting!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatFullDate(DateTime value) {
  const days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  return '${days[value.weekday - 1]}, ${value.day} ${months[value.month - 1]} ${value.year}';
}

class _FocusRow extends StatelessWidget {
  const _FocusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 162,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(action.route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(action.icon),
                ),
                const SizedBox(height: 16),
                Text(
                  action.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Buka cepat',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
