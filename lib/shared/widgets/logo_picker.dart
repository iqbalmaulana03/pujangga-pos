import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/services/business_logo_service.dart';
import 'business_logo.dart';

final logoFilePickerProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
      withData: false,
    );
    if (result == null) return null;
    final path = result.files.single.path;
    if (path == null) {
      throw const AppException(
        'logo_unreadable',
        'Gambar tidak dapat dibaca. Pilih file lokal.',
      );
    }
    return path;
  },
);

/// Drafts are temporary; the repository copies them before committing a profile.
class LogoPicker extends ConsumerStatefulWidget {
  const LogoPicker({
    super.key,
    this.path,
    required this.onChanged,
    this.enabled = true,
    this.onBusyChanged,
  });
  final String? path;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;

  @override
  ConsumerState<LogoPicker> createState() => _LogoPickerState();
}

class _LogoPickerState extends ConsumerState<LogoPicker> {
  final _drafts = <String>[];
  late final BusinessLogoService _logos;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _logos = ref.read(businessLogoServiceProvider);
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      unawaited(_logos.deleteOwned(draft, draft: true));
    }
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      final path = await ref.read(logoFilePickerProvider)();
      if (path == null || !mounted) return;
      final png = await _logos.normalize(await _logos.readSource(path));
      if (!mounted) return;
      final draft = await _logos.write(png, draft: true);
      if (!mounted) {
        await _logos.deleteOwned(draft, draft: true);
        return;
      }
      _drafts.add(draft);
      widget.onChanged(draft);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is AppException
              ? error.message
              : 'Logo tidak dapat dibaca. Pilih gambar lain.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Logo usaha (opsional)'),
      const SizedBox(height: 8),
      SizedBox(
        width: 64,
        height: 64,
        child: BusinessLogo(
          path: widget.path,
          onError: (context, error, stack) => const Tooltip(
            message: 'Logo tidak dapat dibaca. Pilih logo kembali.',
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
      Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: widget.enabled && !_busy ? _pick : null,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
            label: const Text('Pilih Logo'),
          ),
          if (widget.path != null)
            TextButton(
              onPressed: widget.enabled && !_busy
                  ? () => widget.onChanged(null)
                  : null,
              child: const Text('Hapus Logo'),
            ),
        ],
      ),
      const Text(
        'PNG, JPEG, atau WebP statis, maksimal 10 MiB. Pilih ulang jika logo tidak terbaca.',
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}
