import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/repositories/expense_repository.dart';

class PengeluaranPage extends ConsumerStatefulWidget {
  const PengeluaranPage({this.today = false, this.start, this.end, super.key});

  final bool today;
  final DateTime? start;
  final DateTime? end;

  @override
  ConsumerState<PengeluaranPage> createState() => _PengeluaranPageState();
}

class _PengeluaranPageState extends ConsumerState<PengeluaranPage> {
  late DateTime _start;
  late DateTime _end;
  late int _period;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = widget.today ? 0 : 1;
    _start = widget.today
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month);
    _end = widget.today
        ? DateTime(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month + 1);
    if (widget.start != null &&
        widget.end != null &&
        widget.end!.isAfter(widget.start!)) {
      _start = widget.start!;
      _end = widget.end!;
      _period = 2;
    }
  }

  Future<void> _selectPeriod(int period) async {
    final now = DateTime.now();
    if (period == 2) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year, now.month, now.day),
        helpText: 'Periode pengeluaran',
      );
      if (picked == null || !mounted) return;
      setState(() {
        _period = period;
        _start = picked.start;
        _end = DateTime(picked.end.year, picked.end.month, picked.end.day + 1);
      });
      return;
    }
    setState(() {
      _period = period;
      _start = period == 0
          ? DateTime(now.year, now.month, now.day)
          : DateTime(now.year, now.month);
      _end = period == 0
          ? DateTime(now.year, now.month, now.day + 1)
          : DateTime(now.year, now.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(expenseEntriesProvider((_start, _end)));
    final format = DateFormat('d MMM yyyy', 'id_ID');
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text('Pengeluaran'),
        backgroundColor: const Color(0xFFF8FAF8),
        foregroundColor: const Color(0xFF0D5C56),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addExpense),
        backgroundColor: const Color(0xFF0D5C56),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Pengeluaran'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (index, label) in [
                      (0, 'Hari ini'),
                      (1, 'Bulan ini'),
                      (2, 'Pilih tanggal'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _period == index,
                        onSelected: (_) => _selectPeriod(index),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${format.format(_start)} – ${format.format(_end.subtract(const Duration(days: 1)))}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF3F4947),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Data pengeluaran gagal dimuat.'),
                    TextButton(
                      onPressed: () => ref.invalidate(
                        expenseEntriesProvider((_start, _end)),
                      ),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (rows) {
                final total = rows.fold<double>(
                  0,
                  (sum, row) => sum + (row['amount'] as num).toDouble(),
                );
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(expenseEntriesProvider((_start, _end)));
                    await ref.read(
                      expenseEntriesProvider((_start, _end)).future,
                    );
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: rows.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFECEEED)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Pengeluaran',
                                style: TextStyle(color: Color(0xFF3F4947)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                CurrencyFormatter.format(total),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFBA1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${rows.length} pengeluaran pada periode ini',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF3F4947),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (index == 1) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            rows.isEmpty
                                ? 'Belum ada pengeluaran pada periode ini.'
                                : 'Riwayat Pengeluaran',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }
                      final row = rows[index - 2];
                      final notes = row['notes'] as String?;
                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFECEEED)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      row['category'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      CurrencyFormatter.format(
                                        (row['amount'] as num).toDouble(),
                                      ),
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFBA1A1A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                format.format(
                                  DateTime.parse(row['expense_date'] as String),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF3F4947),
                                ),
                              ),
                              if (notes != null && notes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  notes,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF3F4947),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
