import 'package:flutter/material.dart';

import '../../../../shared/widgets/logo_picker.dart';
import '../../domain/entities/business_profile.dart';

class BusinessProfileDialog extends StatefulWidget {
  const BusinessProfileDialog({super.key, this.profile, required this.onSave});
  final BusinessProfile? profile;
  final Future<bool> Function(BusinessProfile) onSave;
  @override
  State<BusinessProfileDialog> createState() => _BusinessProfileDialogState();
}

class _BusinessProfileDialogState extends State<BusinessProfileDialog> {
  final _form = GlobalKey<FormState>();
  late final List<TextEditingController> _fields;
  String? _logo;
  bool _saving = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _fields = [
      p?.businessName,
      p?.businessType,
      p?.ownerName,
      p?.contactNumber,
      p?.address,
    ].map((s) => TextEditingController(text: s ?? '')).toList();
    _logo = p?.logoPath;
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    String? optional(int i) =>
        _fields[i].text.trim().isEmpty ? null : _fields[i].text.trim();
    try {
      final ok = await widget.onSave(
        BusinessProfile(
          businessName: _fields[0].text.trim(),
          businessType: _fields[1].text.trim(),
          ownerName: optional(2),
          contactNumber: optional(3),
          address: optional(4),
          logoPath: _logo,
          modalAwalUsaha: widget.profile?.modalAwalUsaha,
        ),
      );
      if (ok && mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_picking,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Profil Usaha'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _fields.length; i++) ...[
                TextFormField(
                  controller: _fields[i],
                  enabled: !_saving,
                  decoration: InputDecoration(
                    labelText: const [
                      'Nama Usaha',
                      'Jenis Usaha',
                      'Nama Pemilik (Opsional)',
                      'Nomor Kontak (Opsional)',
                      'Alamat (Opsional)',
                    ][i],
                    border: const UnderlineInputBorder(),
                  ),
                  validator: i < 2
                      ? (s) =>
                            s == null || s.trim().isEmpty ? 'Wajib diisi' : null
                      : null,
                  maxLines: i == 4 ? 2 : 1,
                  keyboardType: i == 3
                      ? TextInputType.phone
                      : TextInputType.text,
                ),
                const SizedBox(height: 12),
              ],
              LogoPicker(
                path: _logo,
                enabled: !_saving,
                onChanged: (path) => setState(() => _logo = path),
                onBusyChanged: (value) => setState(() => _picking = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving || _picking ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving || _picking ? null : _save,
          child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    ),
  );
}
