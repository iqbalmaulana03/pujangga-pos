import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/stock_adjustment_request.dart';
import '../../domain/entities/stock_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../controllers/stok_controller.dart';

class DetailStokPage extends ConsumerWidget {
  const DetailStokPage({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(stockItemDetailProvider(itemId));
    final movementAsync = ref.watch(stockMovementDetailProvider(itemId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Stok')),
      body: itemAsync.when(
        data: (item) {
          if (item == null) {
            return const _MissingItemState();
          }

          return movementAsync.when(
            data: (movements) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _ItemSummaryCard(item: item),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aksi Stok',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lakukan penyesuaian manual untuk koreksi stok opname, barang rusak, atau stok masuk.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) {
                                return _AdjustmentSheet(item: item);
                              },
                            ),
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('Sesuaikan Stok'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Histori Pergerakan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (movements.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.history_toggle_off_rounded,
                              size: 42,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Belum ada histori stok',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Pergerakan stok dari transaksi dan penyesuaian manual akan muncul di sini.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < movements.length;
                              index++
                            ) ...[
                              _MovementTile(movement: movements[index]),
                              if (index != movements.length - 1)
                                const Divider(height: 24),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(message: error.toString()),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(message: error.toString()),
      ),
    );
  }
}

class _ItemSummaryCard extends StatelessWidget {
  const _ItemSummaryCard({required this.item});

  final StockItem item;

  @override
  Widget build(BuildContext context) {
    final stockTone = item.isLowStock
        ? const Color(0xFF9C4F1A)
        : const Color(0xFF11564F);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(
                  label: item.category,
                  backgroundColor: const Color(0xFFECE5D8),
                ),
                _InfoPill(
                  label: item.isActive ? 'Aktif' : 'Nonaktif',
                  backgroundColor: item.isActive
                      ? const Color(0xFFDDEEE7)
                      : const Color(0xFFF0E0D4),
                ),
                if ((item.sku ?? '').isNotEmpty)
                  _InfoPill(
                    label: 'SKU ${item.sku}',
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    label: 'Stok Saat Ini',
                    value: '${item.currentStock} ${item.unitLabel ?? 'pcs'}',
                    accent: stockTone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryStat(
                    label: 'Harga Jual',
                    value: CurrencyFormatter.format(item.sellingPrice),
                    accent: const Color(0xFF11564F),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.backgroundColor});

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) {
    final isDecrease = movement.quantityChange < 0;
    final accent = switch (movement.movementType) {
      'manual_add' => const Color(0xFF11564F),
      'manual_reduce' => const Color(0xFF9C4F1A),
      'set_balance' => const Color(0xFF6B4A8B),
      _ => const Color(0xFF5F5E5B),
    };
    final icon = switch (movement.movementType) {
      'manual_add' => Icons.arrow_downward_rounded,
      'manual_reduce' => Icons.arrow_upward_rounded,
      'set_balance' => Icons.sync_alt_rounded,
      _ => Icons.point_of_sale_outlined,
    };
    final quantityLabel =
        '${isDecrease ? '' : '+'}${movement.quantityChange.toStringAsFixed(0)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _movementLabel(movement),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateTime(movement.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Stok ${movement.quantityBefore.toStringAsFixed(0)} -> ${movement.quantityAfter.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if ((movement.notes ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  movement.notes!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          quantityLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _AdjustmentSheet extends ConsumerStatefulWidget {
  const _AdjustmentSheet({required this.item});

  final StockItem item;

  @override
  ConsumerState<_AdjustmentSheet> createState() => _AdjustmentSheetState();
}

class _AdjustmentSheetState extends ConsumerState<_AdjustmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  String _adjustmentType = 'manual_add';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sesuaikan Stok',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _adjustmentType,
                decoration: const InputDecoration(
                  labelText: 'Jenis penyesuaian',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'manual_add',
                    child: Text('Tambah stok'),
                  ),
                  DropdownMenuItem(
                    value: 'manual_reduce',
                    child: Text('Kurangi stok'),
                  ),
                  DropdownMenuItem(
                    value: 'set_balance',
                    child: Text('Set stok akhir'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _adjustmentType = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _adjustmentType == 'set_balance'
                      ? 'Stok akhir'
                      : 'Jumlah penyesuaian',
                ),
                validator: (value) {
                  final quantity = int.tryParse((value ?? '').trim());
                  if (quantity == null) {
                    return 'Masukkan angka yang valid.';
                  }
                  if (quantity < 0) {
                    return 'Jumlah tidak boleh negatif.';
                  }
                  if (_adjustmentType != 'set_balance' && quantity == 0) {
                    return 'Jumlah harus lebih dari 0.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText: 'Contoh: stok opname, barang rusak, restock pagi',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(
                    _isSubmitting ? 'Menyimpan...' : 'Simpan Penyesuaian',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(stokControllerProvider.notifier)
          .submitAdjustment(
            StockAdjustmentRequest(
              itemId: widget.item.id,
              adjustmentType: _adjustmentType,
              quantity: double.parse(_quantityController.text.trim()),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            ),
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Penyesuaian stok berhasil disimpan.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _MissingItemState extends StatelessWidget {
  const _MissingItemState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Item stok tidak ditemukan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Barang ini mungkin sudah dihapus atau bukan item bertipe barang.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat detail stok',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _movementLabel(StockMovement movement) {
  switch (movement.movementType) {
    case 'manual_add':
      return 'Tambah stok manual';
    case 'manual_reduce':
      return 'Kurangi stok manual';
    case 'set_balance':
      return 'Set stok akhir';
    case 'sale':
      return movement.referenceId == null
          ? 'Transaksi penjualan'
          : 'Terjual pada transaksi #${movement.referenceId}';
    default:
      return 'Pergerakan stok';
  }
}

String _formatDateTime(DateTime value) {
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

  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day} ${months[value.month - 1]} ${value.year}, $hour:$minute';
}
