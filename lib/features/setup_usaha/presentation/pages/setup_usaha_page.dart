import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/business_profile.dart';
import '../controllers/setup_usaha_controller.dart';
import '../widgets/business_profile_form.dart';

class SetupUsahaPage extends ConsumerStatefulWidget {
  const SetupUsahaPage({super.key});

  @override
  ConsumerState<SetupUsahaPage> createState() => _SetupUsahaPageState();
}

class _SetupUsahaPageState extends ConsumerState<SetupUsahaPage> {
  Future<void> _submit(BusinessProfile businessProfile) async {
    final controller = ref.read(setupUsahaControllerProvider.notifier);

    try {
      await controller.submit(businessProfile: businessProfile);

      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (error) {
      final message = error is AppException
          ? error.message
          : 'Terjadi kesalahan saat menyimpan profil usaha.';

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(setupUsahaControllerProvider);
    final isLoading = submitState.isLoading;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7F2EC), Color(0xFFF2E7DB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Stack(
                    children: [
                      Positioned(
                        top: -12,
                        right: -4,
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC56E33), Color(0xFF9C4F1A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
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
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Langkah 1 dari 1',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Siapkan Bisnis',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Masukkan profil usaha agar Pujangga POS siap dipakai untuk transaksi harian dengan alur yang sederhana.',
                              style: TextStyle(
                                color: Color(0xFFFBE7D8),
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _HeroPill(
                                  icon: Icons.cloud_off_rounded,
                                  label: 'Local-first',
                                ),
                                _HeroPill(
                                  icon: Icons.lock_person_outlined,
                                  label: 'Tanpa login',
                                ),
                                _HeroPill(
                                  icon: Icons.bolt_rounded,
                                  label: 'Siap operasional cepat',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Isi yang wajib dulu, lengkapi sisanya kapan saja.',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Nama usaha dan jenis usaha sudah cukup untuk menyelesaikan setup awal. Field opsional tetap tersimpan lokal jika diisi sekarang.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  BusinessProfileForm(
                    title: 'Profil Usaha',
                    description:
                        'Form ini mengikuti alur onboarding awal usaha. Gunakan jenis usaha yang paling mendekati operasional harian Anda.',
                    submitLabel: 'Simpan dan Lanjutkan',
                    loading: isLoading,
                    onSubmit: _submit,
                    businessTypeHelperText:
                        'Contoh yang umum: Retail, Kedai Kopi, Barbershop, Toko Bangunan, atau Jasa.',
                    businessTypeSuggestions: const [
                      'Retail',
                      'Kedai Kopi',
                      'Barbershop',
                      'Toko Bangunan',
                      'Jasa',
                    ],
                    optionalSectionHelperText:
                        'Opsional untuk tahap awal. Anda tetap bisa mengubah alamat, kontak, dan nama pemilik dari halaman Pengaturan.',
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

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
