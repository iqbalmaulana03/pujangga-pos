import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../../setup_usaha/domain/entities/business_profile.dart';
import '../../../setup_usaha/presentation/widgets/business_profile_form.dart';
import '../controllers/pengaturan_profil_controller.dart';
import '../controllers/pengaturan_settings_controller.dart';
import '../widgets/app_settings_form.dart';

class PengaturanPage extends ConsumerWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(businessProfileProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final saveState = ref.watch(pengaturanProfilControllerProvider);
    final saveSettingsState = ref.watch(pengaturanSettingsControllerProvider);

    Future<void> handleSubmit(BusinessProfile businessProfile) async {
      final controller = ref.read(pengaturanProfilControllerProvider.notifier);

      try {
        await controller.save(businessProfile);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil usaha berhasil diperbarui.')),
          );
        }
      } catch (error) {
        final message = error is AppException
            ? error.message
            : 'Terjadi kesalahan saat memperbarui profil usaha.';

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }

    Future<void> handleSettingsSubmit(AppSettings settings) async {
      final controller = ref.read(
        pengaturanSettingsControllerProvider.notifier,
      );

      try {
        await controller.save(settings);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preferensi aplikasi berhasil diperbarui.'),
            ),
          );
        }
      } catch (error) {
        final message = error is AppException
            ? error.message
            : 'Terjadi kesalahan saat memperbarui preferensi aplikasi.';

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) => settingsAsync.when(
            data: (settings) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                children: [
                  BusinessProfileForm(
                    title: 'Profil Usaha',
                    description:
                        'Perbarui identitas usaha, kontak, dan referensi logo lokal yang tersimpan di perangkat.',
                    submitLabel: 'Simpan Profil',
                    initialProfile:
                        profile ??
                        const BusinessProfile(
                          businessName: '',
                          businessType: '',
                        ),
                    loading: saveState.isLoading,
                    onSubmit: handleSubmit,
                    header: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengaturan Usaha',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Kelola profil usaha dan preferensi operasional local-first tanpa login atau logout.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppSettingsForm(
                    initialSettings: settings,
                    loading: saveSettingsState.isLoading,
                    onSubmit: handleSettingsSubmit,
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Yang tersimpan lokal',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '1. Nama usaha, jenis usaha, alamat, kontak, pemilik, dan referensi logo disimpan di SQLite.',
                          ),
                          SizedBox(height: 8),
                          Text(
                            '2. Preferensi rupiah, tampilan struk sederhana, pajak default, dan opsi stok minus dapat dipakai ulang modul lain.',
                          ),
                          SizedBox(height: 8),
                          Text(
                            '3. Semua perubahan ditulis lewat repository agar konsisten dengan pendekatan local-first.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal memuat preferensi aplikasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(appSettingsProvider),
                      child: const Text('Muat Ulang'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Gagal memuat profil usaha',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(businessProfileProvider),
                    child: const Text('Muat Ulang'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
