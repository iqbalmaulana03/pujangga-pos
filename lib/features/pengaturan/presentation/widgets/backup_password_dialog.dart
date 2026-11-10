import 'package:flutter/material.dart';

class BackupProtection {
  const BackupProtection(this.password);

  // Null is only returned after explicitly selecting unencrypted export.
  final String? password;
}

class BackupPasswordDialog extends StatefulWidget {
  const BackupPasswordDialog({super.key, required this.creating});

  final bool creating;

  @override
  State<BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<BackupPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _encrypted = true;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.creating ? 'Lindungi Cadangan' : 'Buka Cadangan'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.creating) ...[
                const Text(
                  'Simpan kata sandi di tempat aman. Kata sandi diperlukan untuk memulihkan di perangkat lain dan tidak dapat direset.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enkripsi dengan kata sandi'),
                  value: _encrypted,
                  onChanged: (value) => setState(() => _encrypted = value),
                ),
              ],
              if (_encrypted) ...[
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: 'Kata sandi'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Masukkan kata sandi.';
                    }
                    if (widget.creating && value.length < 12) {
                      return 'Minimal 12 karakter.';
                    }
                    return null;
                  },
                ),
                if (widget.creating)
                  TextFormField(
                    controller: _confirmation,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Ulangi kata sandi',
                    ),
                    validator: (value) => value != _password.text
                        ? 'Kata sandi tidak sama.'
                        : null,
                  ),
              ] else
                const Text(
                  'Tanpa enkripsi, siapa pun yang memperoleh file dapat membaca profil, transaksi, harga modal, dan gaji karyawan. Bagikan hanya kepada pihak tepercaya.',
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(
                context,
                BackupProtection(_encrypted ? _password.text : null),
              );
            }
          },
          child: Text(
            widget.creating
                ? (_encrypted
                      ? 'Cadangkan Terenkripsi'
                      : 'Cadangkan Tanpa Enkripsi')
                : 'Buka Cadangan',
          ),
        ),
      ],
    );
  }
}
