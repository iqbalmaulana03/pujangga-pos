import 'package:flutter/material.dart';

import '../../domain/entities/app_settings.dart';

typedef AppSettingsSubmit = Future<void> Function(AppSettings settings);

class AppSettingsForm extends StatefulWidget {
  const AppSettingsForm({
    required this.initialSettings,
    required this.onSubmit,
    this.loading = false,
    super.key,
  });

  final AppSettings initialSettings;
  final AppSettingsSubmit onSubmit;
  final bool loading;

  @override
  State<AppSettingsForm> createState() => _AppSettingsFormState();
}

class _AppSettingsFormState extends State<AppSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _receiptHeaderController;
  late final TextEditingController _receiptFooterController;
  late final TextEditingController _taxController;
  late bool _stockAllowNegative;

  @override
  void initState() {
    super.initState();
    _receiptHeaderController = TextEditingController(
      text: widget.initialSettings.receiptHeader ?? '',
    );
    _receiptFooterController = TextEditingController(
      text: widget.initialSettings.receiptFooter ?? '',
    );
    _taxController = TextEditingController(
      text: widget.initialSettings.defaultTaxPercent == 0
          ? ''
          : widget.initialSettings.defaultTaxPercent.toStringAsFixed(0),
    );
    _stockAllowNegative = widget.initialSettings.stockAllowNegative;
  }

  @override
  void didUpdateWidget(covariant AppSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSettings != widget.initialSettings) {
      _receiptHeaderController.text =
          widget.initialSettings.receiptHeader ?? '';
      _receiptFooterController.text =
          widget.initialSettings.receiptFooter ?? '';
      _taxController.text = widget.initialSettings.defaultTaxPercent == 0
          ? ''
          : widget.initialSettings.defaultTaxPercent.toStringAsFixed(0);
      _stockAllowNegative = widget.initialSettings.stockAllowNegative;
    }
  }

  @override
  void dispose() {
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  String? _normalizeOptional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await widget.onSubmit(
      AppSettings(
        currencyCode: 'IDR',
        currencySymbol: 'Rp',
        defaultTaxPercent: double.tryParse(_taxController.text.trim()) ?? 0,
        stockAllowNegative: _stockAllowNegative,
        receiptHeader: _normalizeOptional(_receiptHeaderController.text),
        receiptFooter: _normalizeOptional(_receiptFooterController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferensi Operasional',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Preferensi ini disimpan lokal dan bisa dipakai ulang oleh modul transaksi, struk, dan stok.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferensi MVP',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Mata uang default dikunci ke Rupiah untuk MVP. Header dan footer membantu tampilan struk sederhana.',
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    initialValue: 'Rupiah (IDR)',
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Mata uang default',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _taxController,
                    decoration: const InputDecoration(
                      labelText: 'Pajak default (%)',
                      hintText: 'Opsional, contoh: 11',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) {
                        return null;
                      }
                      final parsed = double.tryParse(trimmed);
                      if (parsed == null) {
                        return 'Masukkan angka yang valid.';
                      }
                      if (parsed < 0 || parsed > 100) {
                        return 'Nilai pajak harus 0 sampai 100.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _receiptHeaderController,
                    decoration: const InputDecoration(
                      labelText: 'Header struk',
                      hintText: 'Contoh: Terima kasih sudah berbelanja',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _receiptFooterController,
                    decoration: const InputDecoration(
                      labelText: 'Footer struk',
                      hintText: 'Contoh: Simpan struk ini sebagai bukti',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Izinkan stok minus'),
                    subtitle: const Text(
                      'Preferensi operasional dasar untuk penyesuaian stok dan transaksi jika dibutuhkan.',
                    ),
                    value: _stockAllowNegative,
                    onChanged: widget.loading
                        ? null
                        : (value) {
                            setState(() => _stockAllowNegative = value);
                          },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.loading ? null : _handleSubmit,
              icon: const Icon(Icons.save_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  widget.loading ? 'Menyimpan...' : 'Simpan Preferensi',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
