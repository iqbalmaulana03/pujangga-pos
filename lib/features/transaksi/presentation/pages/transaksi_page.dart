import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:io';
import '../../../../app/router/app_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../laporan/presentation/controllers/laporan_controller.dart';
import '../../../pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import '../../../riwayat/presentation/controllers/riwayat_controller.dart';
import '../../../stok/presentation/controllers/stok_controller.dart';
import '../../domain/entities/transaksi_cart_item.dart';
import '../../domain/entities/transaksi_item.dart';
import '../controllers/transaksi_controller.dart';
import '../models/transaksi_state.dart';

class TransaksiPage extends ConsumerStatefulWidget {
  const TransaksiPage({super.key});

  @override
  ConsumerState<TransaksiPage> createState() => _TransaksiPageState();
}

class _TransaksiPageState extends ConsumerState<TransaksiPage> {
  final _searchController = TextEditingController();
  final _cashController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    final controller = ref.read(transaksiControllerProvider.notifier);

    try {
      final receipt = await controller.submit();
      if (!mounted) {
        return;
      }

      _cashController.clear();
      _searchController.clear();
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(salesReportSnapshotProvider);
      ref.invalidate(stokControllerProvider);
      ref.invalidate(riwayatControllerProvider);

      context.push('${AppRoutes.transactionSuccess}/${receipt.invoiceNumber}');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is AppException
          ? error.message
          : 'Transaksi gagal disimpan. Coba lagi.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _editItemDiscount(
    BuildContext context,
    TransaksiCartItem cartItem,
  ) async {
    final controller = TextEditingController(
      text: cartItem.itemDiscountAmount.toStringAsFixed(0),
    );

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diskon ${cartItem.item.name}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D5C56),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Maksimal ${CurrencyFormatter.format(cartItem.lineSubtotal)} untuk item ini.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF3F4947),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Diskon Item',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: const Color(0xFFF2F4F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0D5C56), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(double.tryParse(controller.text.trim()) ?? 0);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Terapkan Diskon',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      ref
          .read(transaksiControllerProvider.notifier)
          .updateItemDiscount(cartItem.item.id, result);
    }
  }

  Future<void> _editOrderDiscount(
    BuildContext context,
    double currentDiscount,
  ) async {
    final controller = TextEditingController(
      text: currentDiscount.toStringAsFixed(0),
    );

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Diskon Transaksi (Order)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D5C56),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan jumlah potongan harga untuk seluruh pesanan ini.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF3F4947),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Diskon Total',
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: const Color(0xFFF2F4F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0D5C56), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop(double.tryParse(controller.text.trim()) ?? 0);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Terapkan Diskon',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      ref
          .read(transaksiControllerProvider.notifier)
          .updateOrderDiscount(result);
    }
  }

  void _showCartBottomSheet(TransaksiState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final liveState = ref.watch(transaksiControllerProvider).value;
                if (liveState == null || liveState.cartItems.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pop(context);
                  });
                  return const SizedBox.shrink();
                }
                return _buildCartPane(
                  liveState,
                  scrollController: scrollController,
                  isBottomSheet: true,
                );
              },
            );
          },
        );
      },
    );
  }

  void _setCashPaid(double amount) {
    setState(() {
      _cashController.text = amount.toStringAsFixed(0);
    });
    ref.read(transaksiControllerProvider.notifier).updateCashPaid(amount);
  }

  @override
  Widget build(BuildContext context) {
    final transaksiAsync = ref.watch(transaksiControllerProvider);
    final profileAsync = ref.watch(businessProfileProvider);
    final logoPath = profileAsync.asData?.value?.logoPath;

    return transaksiAsync.when(
      data: (state) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildCatalogPane(state, isMobile: false, logoPath: logoPath),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Color(0xFFE1E3E1),
                  ),
                  Expanded(
                    flex: 4,
                    child: _buildCartPane(state, isBottomSheet: false),
                  ),
                ],
              );
            } else {
              return Scaffold(
                backgroundColor: const Color(0xFFF8FAF8),
                body: _buildCatalogPane(state, isMobile: true, logoPath: logoPath),
                bottomNavigationBar: state.cartItems.isNotEmpty
                    ? _buildMobileStickyBottomBar(state)
                    : null,
              );
            }
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFBA1A1A)),
              const SizedBox(height: 16),
              const Text(
                'Gagal memuat modul transaksi',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Inter', color: Color(0xFF3F4947)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => ref.invalidate(transaksiControllerProvider),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D5C56),
                ),
                child: const Text('Muat Ulang'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogPane(TransaksiState state, {required bool isMobile, required String? logoPath}) {
    return Container(
      color: const Color(0xFFF8FAF8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE1E3E1), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: ref
                      .read(transaksiControllerProvider.notifier)
                      .updateSearch,
                  decoration: InputDecoration(
                    hintText: 'Cari barang...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF3F4947)),
                    filled: true,
                    fillColor: const Color(0xFFF2F4F2),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: Color(0xFF0D5C56),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterChip('semua', 'Semua', state.typeFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip('barang', 'Barang', state.typeFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip('jasa', 'Jasa', state.typeFilter),
                  ],
                ),
              ],
            ),
          ),
          // Active Catalog Grid
          Expanded(
            child: state.filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFFBEC9C6)),
                        SizedBox(height: 12),
                        Text(
                          'Katalog kosong atau tidak ditemukan.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFF3F4947),
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 2 : 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: state.filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildCatalogItemCard(state.filteredItems[index], logoPath);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, String currentFilter) {
    final isSelected = currentFilter == value;
    return GestureDetector(
      onTap: () {
        ref.read(transaksiControllerProvider.notifier).updateFilter(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D5C56) : const Color(0xFFECEEED),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF3F4947),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogItemCard(TransaksiItem item, String? logoPath) {
    String? imageUrl;
    final nameLower = item.name.toLowerCase();
    if (nameLower.contains('espresso')) {
      imageUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuC-IY8P8kbPiw7Tj6de85ViUnzT5HFgCr4XYnnLUSaTWS5KCrrwwKTwMgsopdDwXuTdwp6AdRwJlGsyYFJSuF8cIUw-CUyY8kUl-bh6ejEo2O6DsK7s26YlpY0dsf_seWFBMarOo04l12vQpi-IKD9N0BcNgzQVqHhTMcKZtQ_dHyN2VPt8evCNpA4a3OD3MO3LAI8QgjFCDBIfTBfemMW_iA2MYc_h4WDopM-3ObRLPc9nAthjEUx8';
    } else if (nameLower.contains('matcha')) {
      imageUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuCgj_amFzOgHLhGY2wWxTyoT-7ofK0pOwT4djUezgrGDBpqMhJr_44s0-lCXbicDar4Wn4otWMTMSs-kcQIfhOzg5hQdz6T87B2ZAMjtYUe4AMsZT_Q5VD71itpaW0Kg4E0DjMFqCXhTHDoSb9Os57PjQlFGOCHR1WhKs50I-uccWPZ3jqki0LP17RMOqsJujimbY0GikVmvhhbCUKkmplEEnt3ksXnJMkkgMd6Ti3xBM9e-mG-wGIN';
    } else if (nameLower.contains('croissant')) {
      imageUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuDtw6FzoRqsgJnhCOMFExNBi-djCa-zF3rZDMdZOLFbH4bTzKIjXoBSUMo3v0dWBy7boOi0M6UuQiivP5poXcYwYgSrPPiefB9lKppiE5ND6zqXFMnqqqiywwHLiOxp62DhWEJH32LLCSAa0Pki_GcRlZsv_TtPC8ve8lo-R8H4R5Q5cQO34yMXSMHnNP2cODt_TgHWJWlbEIo2AswHm0foxdgL3BwPnTL9vuIe8qsBhlh4ZlBgX8Xf';
    }

    return GestureDetector(
      onTap: () {
        ref.read(transaksiControllerProvider.notifier).addItem(item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE1E3E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image area
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? Image.network(imageUrl, fit: BoxFit.cover)
                      : (logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync())
                          ? Image.file(
                              File(logoPath),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: const Color(0xFFECEEED),
                              child: const Icon(
                                Icons.storefront,
                                size: 28,
                                color: Color(0xFFBEC9C6),
                              ),
                            ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details area
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191C1C),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            CurrencyFormatter.format(item.sellingPrice),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D5C56),
                            ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFFECEEED),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 14,
                            color: Color(0xFF0D5C56),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartPane(
    TransaksiState state, {
    ScrollController? scrollController,
    required bool isBottomSheet,
  }) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keranjang Transaksi',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191C1C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pelanggan Walk-in',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: const Color(0xFF3F4947).withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    ref.read(transaksiControllerProvider.notifier).clearCart();
                  },
                  tooltip: 'Hapus Semua',
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFBA1A1A)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE1E3E1)),
          // Items List
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: state.cartItems.length,
              itemBuilder: (context, index) {
                final cartItem = state.cartItems[index];
                return Column(
                  children: [
                    _buildCartItemRow(cartItem),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F2)),
                  ],
                );
              },
            ),
          ),
          // calculations & checkout panel
          _buildCartCheckoutSummary(state, isBottomSheet: isBottomSheet),
        ],
      ),
    );
  }

  Widget _buildCartItemRow(TransaksiCartItem cartItem) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartItem.item.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cartItem.item.category} • ${cartItem.item.isBarang ? "Barang" : "Jasa"}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF3F4947),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _editItemDiscount(context, cartItem),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cartItem.itemDiscountAmount > 0
                              ? const Color(0xFFFFDAD6)
                              : const Color(0xFFECEEED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.percent,
                              size: 12,
                              color: cartItem.itemDiscountAmount > 0
                                  ? const Color(0xFFBA1A1A)
                                  : const Color(0xFF0D5C56),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cartItem.itemDiscountAmount > 0
                                  ? '-${CurrencyFormatter.format(cartItem.itemDiscountAmount)}'
                                  : 'Diskon Item',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: cartItem.itemDiscountAmount > 0
                                    ? const Color(0xFFBA1A1A)
                                    : const Color(0xFF0D5C56),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(cartItem.lineTotal),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D5C56),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Qty counter buttons
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBEC9C6)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    ref
                        .read(transaksiControllerProvider.notifier)
                        .decreaseQuantity(cartItem.item.id);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(Icons.remove, size: 16, color: Color(0xFF3F4947)),
                  ),
                ),
                Text(
                  '${cartItem.quantity}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191C1C),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    ref
                        .read(transaksiControllerProvider.notifier)
                        .increaseQuantity(cartItem.item.id);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Icon(Icons.add, size: 16, color: Color(0xFF3F4947)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartCheckoutSummary(TransaksiState state, {required bool isBottomSheet}) {
    final isCash = state.paymentMethod == 'tunai';

    // Calculate dynamic helper buttons
    final pasAmount = state.totalAmount;
    double nextFifty = ((state.totalAmount / 50000).ceil() * 50000).toDouble();
    if (nextFifty == pasAmount) {
      nextFifty += 50000;
    }
    double nextHundred = ((state.totalAmount / 100000).ceil() * 100000).toDouble();
    if (nextHundred == pasAmount || nextHundred == nextFifty) {
      nextHundred += 100000;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, isBottomSheet ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE1E3E1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Calculations rows
          _buildCalculationRow(
            'Subtotal (${state.cartItems.length} item)',
            CurrencyFormatter.format(state.subtotalAmount),
          ),
          if (state.itemDiscountAmount > 0)
            _buildCalculationRow(
              'Diskon Item',
              '-${CurrencyFormatter.format(state.itemDiscountAmount)}',
              textColor: const Color(0xFFBA1A1A),
            ),
          _buildCalculationRow(
            'Diskon Transaksi',
            state.orderDiscountAmount > 0
                ? '-${CurrencyFormatter.format(state.orderDiscountAmount)}'
                : 'Tambah Diskon',
            textColor: state.orderDiscountAmount > 0 ? const Color(0xFFBA1A1A) : const Color(0xFF0D5C56),
            isAction: true,
            onTap: () => _editOrderDiscount(context, state.orderDiscountAmount),
          ),
          _buildCalculationRow(
            'Pajak (${(ref.watch(appSettingsProvider).asData?.value.defaultTaxPercent ?? 0.0).toStringAsFixed(0)}%)',
            CurrencyFormatter.format(state.taxAmount),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1C),
                ),
              ),
              Text(
                CurrencyFormatter.format(state.totalAmount),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D5C56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Payment Method Selector Label
          const Text(
            'METODE PEMBAYARAN',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F4947),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Payment Methods Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const {
                  'tunai': 'Tunai',
                  'transfer': 'Transfer',
                  'qris': 'QRIS',
                  'ewallet': 'E-Wallet',
                  'kartu': 'Kartu',
                }.entries) ...[
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(transaksiControllerProvider.notifier)
                          .updatePaymentMethod(entry.key);
                      if (entry.key != 'tunai') {
                        _cashController.clear();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: state.paymentMethod == entry.key
                            ? const Color(0xFF0D5C56)
                            : const Color(0xFFECEEED),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: state.paymentMethod == entry.key
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: state.paymentMethod == entry.key
                              ? Colors.white
                              : const Color(0xFF3F4947),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          if (isCash) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'JUMLAH DITERIMA',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F4947),
                  ),
                ),
                if (state.changeAmount > 0)
                  Text(
                    'Kembalian: ${CurrencyFormatter.format(state.changeAmount)}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D5C56),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text(
                    'Rp',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D5C56),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _cashController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191C1C),
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: '0',
                      ),
                      onChanged: (value) {
                        final parsed = double.tryParse(value.trim());
                        ref
                            .read(transaksiControllerProvider.notifier)
                            .updateCashPaid(parsed);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Quick Cash Options Row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _setCashPaid(pasAmount),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFF0D5C56)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Uang Pas',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D5C56),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _setCashPaid(nextFifty),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEEED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Rp ${nextFifty >= 1000 ? "${(nextFifty / 1000).toStringAsFixed(0)}k" : nextFifty.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF3F4947),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _setCashPaid(nextHundred),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEEED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Rp ${nextHundred >= 1000 ? "${(nextHundred / 1000).toStringAsFixed(0)}k" : nextHundred.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF3F4947),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Process Button
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: state.isSubmitting || !state.canSubmit ? null : _submitTransaction,
              icon: const Icon(Icons.payments_outlined, size: 20),
              label: Text(
                state.isSubmitting ? 'Memproses...' : 'Proses Pembayaran',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C56),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    String value, {
    Color? textColor,
    bool isAction = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFF3F4947),
            ),
          ),
          GestureDetector(
            onTap: isAction ? onTap : null,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isAction ? FontWeight.bold : FontWeight.normal,
                color: textColor ?? const Color(0xFF191C1C),
                decoration: isAction ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStickyBottomBar(TransaksiState state) {
    return SafeArea(
      child: GestureDetector(
        onTap: () => _showCartBottomSheet(state),
        child: Container(
          height: 56,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D5C56),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${state.cartItems.length} item • ${CurrencyFormatter.format(state.totalAmount)}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                children: const [
                  Text(
                    'Keranjang',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
