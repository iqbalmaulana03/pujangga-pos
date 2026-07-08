import 'package:flutter/material.dart';

import '../../domain/entities/business_profile.dart';

typedef BusinessProfileSubmit =
    Future<void> Function(BusinessProfile businessProfile);

class BusinessProfileForm extends StatefulWidget {
  const BusinessProfileForm({
    required this.title,
    required this.description,
    required this.submitLabel,
    required this.onSubmit,
    this.initialProfile,
    this.loading = false,
    this.header,
    this.businessTypeHelperText,
    this.businessTypeSuggestions = const [],
    this.optionalSectionHelperText,
    super.key,
  });

  final String title;
  final String description;
  final String submitLabel;
  final BusinessProfileSubmit onSubmit;
  final BusinessProfile? initialProfile;
  final bool loading;
  final Widget? header;
  final String? businessTypeHelperText;
  final List<String> businessTypeSuggestions;
  final String? optionalSectionHelperText;

  @override
  State<BusinessProfileForm> createState() => _BusinessProfileFormState();
}

class _BusinessProfileFormState extends State<BusinessProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessNameController;
  late final TextEditingController _businessTypeController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactNumberController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _logoPathController;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController(
      text: widget.initialProfile?.businessName ?? '',
    );
    _businessTypeController = TextEditingController(
      text: widget.initialProfile?.businessType ?? '',
    );
    _addressController = TextEditingController(
      text: widget.initialProfile?.address ?? '',
    );
    _contactNumberController = TextEditingController(
      text: widget.initialProfile?.contactNumber ?? '',
    );
    _ownerNameController = TextEditingController(
      text: widget.initialProfile?.ownerName ?? '',
    );
    _logoPathController = TextEditingController(
      text: widget.initialProfile?.logoPath ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant BusinessProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialProfile != widget.initialProfile &&
        widget.initialProfile != null) {
      _businessNameController.text = widget.initialProfile?.businessName ?? '';
      _businessTypeController.text = widget.initialProfile?.businessType ?? '';
      _addressController.text = widget.initialProfile?.address ?? '';
      _contactNumberController.text =
          widget.initialProfile?.contactNumber ?? '';
      _ownerNameController.text = widget.initialProfile?.ownerName ?? '';
      _logoPathController.text = widget.initialProfile?.logoPath ?? '';
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _ownerNameController.dispose();
    _logoPathController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await widget.onSubmit(
      BusinessProfile(
        businessName: _businessNameController.text.trim(),
        businessType: _businessTypeController.text.trim(),
        address: _normalizeOptional(_addressController.text),
        contactNumber: _normalizeOptional(_contactNumberController.text),
        ownerName: _normalizeOptional(_ownerNameController.text),
        logoPath: _normalizeOptional(_logoPathController.text),
      ),
    );
  }

  String? _normalizeOptional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  void _applyBusinessTypeSuggestion(String value) {
    _businessTypeController.text = value;
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.header != null) ...[
            widget.header!,
            const SizedBox(height: 24),
          ],
          Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(widget.description),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi Utama',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Isi dua field inti ini agar aplikasi siap dipakai untuk operasional pertama.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _businessNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama usaha',
                      hintText: 'Contoh: Toko Ikan Segar',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nama usaha wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _businessTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Jenis usaha',
                      hintText: 'Contoh: Retail, Kedai Kopi, Barbershop',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Jenis usaha wajib diisi';
                      }
                      return null;
                    },
                  ),
                  if (widget.businessTypeHelperText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.businessTypeHelperText!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (widget.businessTypeSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final suggestion in widget.businessTypeSuggestions)
                          ActionChip(
                            label: Text(suggestion),
                            onPressed: () =>
                                _applyBusinessTypeSuggestion(suggestion),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lengkapi Jika Perlu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.optionalSectionHelperText ??
                        'Field ini opsional dan bisa diperbarui lagi dari menu Pengaturan.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama pemilik',
                      hintText: 'Opsional',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor kontak',
                      hintText: 'Opsional',
                    ),
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Alamat',
                      hintText: 'Opsional',
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _logoPathController,
                    decoration: const InputDecoration(
                      labelText: 'Referensi logo lokal',
                      hintText: 'Contoh: /storage/emulated/0/Pictures/logo.png',
                    ),
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
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  widget.loading ? 'Menyimpan...' : widget.submitLabel,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Data tersimpan lokal di perangkat dan dapat diubah kembali kapan saja.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
