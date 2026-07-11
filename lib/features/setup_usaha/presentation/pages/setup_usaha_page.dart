import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/business_profile.dart';
import '../controllers/setup_usaha_controller.dart';

class SetupUsahaPage extends ConsumerStatefulWidget {
  const SetupUsahaPage({super.key});

  @override
  ConsumerState<SetupUsahaPage> createState() => _SetupUsahaPageState();
}

class _SetupUsahaPageState extends ConsumerState<SetupUsahaPage> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  String? _selectedCategory;
  String _selectedCurrency = 'IDR';

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih Kategori Bisnis terlebih dahulu.'),
        ),
      );
      return;
    }

    final businessProfile = BusinessProfile(
      businessName: _businessNameController.text.trim(),
      businessType: _selectedCategory!,
    );

    final controller = ref.read(setupUsahaControllerProvider.notifier);

    try {
      await controller.submit(
        businessProfile: businessProfile,
        currencyCode: _selectedCurrency,
      );

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
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: const Color(0xFFF8FAF8),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        automaticallyImplyLeading: false,
        title: Row(
          children: const [
            Icon(
              Icons.storefront,
              color: Color(0xFF0D5C56),
            ),
            SizedBox(width: 8),
            Text(
              'Pujangga-POS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D5C56),
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFBEC9C6),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Ambient Gradient Blur Background
          Positioned(
            top: -128,
            left: -128,
            child: Container(
              width: 384,
              height: 384,
              decoration: BoxDecoration(
                color: const Color(0xFF0D5C56).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -200,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                color: const Color(0xFFE1DFDB).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.shrink(),
            ),
          ),
          // Form and content card scrollable on top
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 450),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE1E3E1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rocket Icon Header
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D5C56),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.rocket_launch,
                          color: Color(0xFF8ED2CA),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Headings
                      const Text(
                        'Selamat Datang di Pujangga-POS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D5C56),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mari siapkan toko Anda dalam beberapa langkah mudah.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF3F4947),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Nama Toko / Bisnis Field
                      Align(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Nama Toko / Bisnis',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF191C1C),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _businessNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF2F4F2),
                          prefixIcon: const Icon(
                            Icons.store,
                            color: Color(0xFF3F4947),
                          ),
                          hintText: 'Contoh: Toko Berkah',
                          hintStyle: const TextStyle(
                            color: Color(0xFF3F4947),
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFFBEC9C6),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF0D5C56),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          errorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          focusedErrorBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama toko wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Kategori Bisnis Grid
                      Align(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Kategori Bisnis',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF191C1C),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _CategoryCard(
                              icon: Icons.set_meal,
                              label: 'Toko Ikan',
                              selected: _selectedCategory == 'Toko Ikan',
                              onTap: () => setState(
                                () => _selectedCategory = 'Toko Ikan',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CategoryCard(
                              icon: Icons.local_cafe,
                              label: 'Kedai Kopi',
                              selected: _selectedCategory == 'Kedai Kopi',
                              onTap: () => setState(
                                () => _selectedCategory = 'Kedai Kopi',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _CategoryCard(
                              icon: Icons.handyman,
                              label: 'Toko Bangunan',
                              selected: _selectedCategory == 'Toko Bangunan',
                              onTap: () => setState(
                                () => _selectedCategory = 'Toko Bangunan',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CategoryCard(
                              icon: Icons.local_convenience_store,
                              label: 'Toko Kelontong',
                              selected: _selectedCategory == 'Toko Kelontong',
                              onTap: () => setState(
                                () => _selectedCategory = 'Toko Kelontong',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _CategoryCard(
                        icon: Icons.content_cut,
                        label: 'Pangkas Rambut',
                        selected: _selectedCategory == 'Pangkas Rambut',
                        onTap: () => setState(
                          () => _selectedCategory = 'Pangkas Rambut',
                        ),
                        isFullWidth: true,
                      ),
                      const SizedBox(height: 20),
                      // Mata Uang Dropdown
                      Align(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Mata Uang',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF191C1C),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedCurrency,
                        icon: const Icon(
                          Icons.expand_more,
                          color: Color(0xFF3F4947),
                        ),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF191C1C),
                        ),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color(0xFFF2F4F2),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFFBEC9C6),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF0D5C56),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'IDR',
                            child: Text('IDR - Rupiah Indonesia (Rp)'),
                          ),
                          DropdownMenuItem(
                            value: 'USD',
                            child: Text('USD - Dolar AS (\$)'),
                          ),
                          DropdownMenuItem(
                            value: 'SGD',
                            child: Text('SGD - Dolar Singapura (S\$)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCurrency = val);
                          }
                        },
                      ),
                      const SizedBox(height: 32),
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0D5C56),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLoading
                                    ? 'MENYIMPAN...'
                                    : 'MULAI BISNIS SAYA',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isFullWidth = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? const Color(0xFF0D5C56)
        : const Color(0xFFFFFFFF);
    final borderColor = selected
        ? const Color(0xFF0D5C56)
        : const Color(0xFFBEC9C6);
    final contentColor = selected
        ? const Color(0xFF8ED2CA)
        : const Color(0xFF3F4947);
    final textColor = selected
        ? const Color(0xFF8ED2CA)
        : const Color(0xFF191C1C);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: borderColor,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: contentColor, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
