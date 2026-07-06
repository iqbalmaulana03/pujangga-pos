import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../controllers/setup_usaha_controller.dart';

class SetupUsahaPage extends ConsumerStatefulWidget {
  const SetupUsahaPage({super.key});

  @override
  ConsumerState<SetupUsahaPage> createState() => _SetupUsahaPageState();
}

class _SetupUsahaPageState extends ConsumerState<SetupUsahaPage> {
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(setupUsahaControllerProvider.notifier);

    try {
      await controller.submit(
        businessName: _businessNameController.text,
        businessType: _businessTypeController.text,
      );

      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(setupUsahaControllerProvider);
    final isLoading = submitState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE0C7), Color(0xFFF7C99B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Siapkan Bisnis',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Langkah awal untuk mengaktifkan operasional Pujangga POS. Skeleton ini sudah menyiapkan penyimpanan lokal dan redirect startup.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _businessNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama usaha',
                          hintText: 'Contoh: Toko Ikan Segar',
                        ),
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Jenis usaha wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: isLoading ? null : _submit,
                          child: Text(
                            isLoading ? 'Menyimpan...' : 'Simpan dan Lanjutkan',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Fondasi issue #1 yang aktif di layar ini',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '1. App start mengecek status setup sebelum menentukan route awal.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '2. Form setup menyimpan profil bisnis ke SQLite lewat repository.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          '3. Setelah setup selesai, pengguna diarahkan ke shell navigasi utama.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
