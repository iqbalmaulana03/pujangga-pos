import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'dart:io';
import '../../../../app/router/app_router.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/catalog_item.dart';
import '../controllers/katalog_controller.dart';

class KatalogPage extends ConsumerStatefulWidget {
  const KatalogPage({super.key});

  @override
  ConsumerState<KatalogPage> createState() => _KatalogPageState();
}

class _KatalogPageState extends ConsumerState<KatalogPage> {
  final _searchController = TextEditingController();
  int _selectedTab = 0; // 0: Produk, 1: Layanan, 2: Kategori
  bool _onlyAvailable = false;
  bool _onlyLowStock = false;
  String _selectedStatus = 'semua'; // 'semua', 'aktif', 'nonaktif'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showStatusFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Status Item',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF191C1C),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Semua Status'),
                trailing: _selectedStatus == 'semua'
                    ? const Icon(Icons.check, color: Color(0xFF0D5C56))
                    : null,
                onTap: () {
                  setState(() {
                    _selectedStatus = 'semua';
                  });
                  ref
                      .read(katalogControllerProvider.notifier)
                      .updateStatusFilter('semua');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Aktif'),
                trailing: _selectedStatus == 'aktif'
                    ? const Icon(Icons.check, color: Color(0xFF0D5C56))
                    : null,
                onTap: () {
                  setState(() {
                    _selectedStatus = 'aktif';
                  });
                  ref
                      .read(katalogControllerProvider.notifier)
                      .updateStatusFilter('aktif');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Nonaktif'),
                trailing: _selectedStatus == 'nonaktif'
                    ? const Icon(Icons.check, color: Color(0xFF0D5C56))
                    : null,
                onTap: () {
                  setState(() {
                    _selectedStatus = 'nonaktif';
                  });
                  ref
                      .read(katalogControllerProvider.notifier)
                      .updateStatusFilter('nonaktif');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final katalogAsync = ref.watch(katalogControllerProvider);
    final profileAsync = ref.watch(businessProfileProvider);
    final logoPath = profileAsync.asData?.value?.logoPath;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: katalogAsync.when(
        data: (state) {
          final filtered = state.filteredItems.where((item) {
            if (_onlyAvailable) {
              if (!item.isActive) return false;
              if (item.isBarang && (item.stockQuantity ?? 0) <= 0) return false;
            }
            if (_onlyLowStock && _selectedTab == 0) {
              if (!item.isActive) return false;
              if (!item.isBarang) return false;
              if ((item.stockQuantity ?? 0) > 5) return false;
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () => ref.refresh(katalogControllerProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderArea(),
                const SizedBox(height: 20),
                _buildTabsArea(),
                const SizedBox(height: 16),
                if (_selectedTab != 2) ...[
                  _buildToolbarArea(),
                  const SizedBox(height: 16),
                ],
                _selectedTab == 2
                    ? _buildCategoryView(state.allItems)
                    : _buildItemGrid(filtered, logoPath),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Gagal memuat katalog',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(katalogControllerProvider),
                    child: const Text('Muat Ulang'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: _selectedTab != 2
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.catalogCreate),
              backgroundColor: const Color(0xFF0D5C56),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildHeaderArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final headerContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Katalog',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1C),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Kelola produk dan layanan Anda',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF3F4947),
              ),
            ),
          ],
        );

        final searchInput = SizedBox(
          width: isWide ? 320 : double.infinity,
          height: 48,
          child: TextField(
            controller: _searchController,
            onChanged: ref
                .read(katalogControllerProvider.notifier)
                .updateSearch,
            decoration: InputDecoration(
              hintText: 'Cari katalog...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF3F4947)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              filled: true,
              fillColor: const Color(0xFFF2F4F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Color(0xFFBEC9C6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Color(0xFFBEC9C6)),
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
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              headerContent,
              searchInput,
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerContent,
              const SizedBox(height: 16),
              searchInput,
            ],
          );
        }
      },
    );
  }

  Widget _buildTabsArea() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE1E3E1), width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Produk'),
          _buildTabButton(1, 'Layanan'),
          _buildTabButton(2, 'Kategori'),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isActive = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
        if (index == 0) {
          ref
              .read(katalogControllerProvider.notifier)
              .updateTypeFilter('barang');
        } else if (index == 1) {
          ref
              .read(katalogControllerProvider.notifier)
              .updateTypeFilter('jasa');
        } else {
          ref
              .read(katalogControllerProvider.notifier)
              .updateTypeFilter('semua');
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF0D5C56) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF0D5C56) : const Color(0xFF3F4947),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarArea() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showStatusFilterBottomSheet,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBEC9C6)),
                      color: _selectedStatus != 'semua'
                          ? const Color(0xFF0D5C56).withValues(alpha: 0.08)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 16,
                          color: _selectedStatus != 'semua'
                              ? const Color(0xFF0D5C56)
                              : const Color(0xFF3F4947),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedStatus == 'semua'
                              ? 'Filter'
                              : _selectedStatus == 'aktif'
                                  ? 'Status: Aktif'
                                  : 'Status: Nonaktif',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _selectedStatus != 'semua'
                                ? const Color(0xFF0D5C56)
                                : const Color(0xFF3F4947),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _onlyAvailable = !_onlyAvailable;
                    });
                  },
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _onlyAvailable
                            ? const Color(0xFF0D5C56)
                            : const Color(0xFFBEC9C6),
                      ),
                      color: _onlyAvailable
                          ? const Color(0xFF0D5C56).withValues(alpha: 0.08)
                          : Colors.transparent,
                    ),
                    child: Text(
                      'Tersedia',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: _onlyAvailable
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _onlyAvailable
                            ? const Color(0xFF0D5C56)
                            : const Color(0xFF3F4947),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedTab == 0)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _onlyLowStock = !_onlyLowStock;
                      });
                    },
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _onlyLowStock
                              ? const Color(0xFFBA1A1A)
                              : const Color(0xFFBEC9C6),
                        ),
                        color: _onlyLowStock
                            ? const Color(0xFFFFDAD6)
                            : Colors.transparent,
                      ),
                      child: Text(
                        'Stok Menipis',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: _onlyLowStock
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _onlyLowStock
                              ? const Color(0xFFBA1A1A)
                              : const Color(0xFF3F4947),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemGrid(List<CatalogItem> items, String? logoPath) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: const [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Color(0xFFBEC9C6),
              ),
              SizedBox(height: 16),
              Text(
                'Tidak ada item yang cocok',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F4947),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ubah kata kunci pencarian atau filter Anda.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF3F4947),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 480 ? 2 : (width < 800 ? 3 : 4);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.60,
          ),
          itemCount: items.length + (crossAxisCount > 2 ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == items.length) {
              return _buildGhostCard();
            }
            return _buildProductCard(items[index], logoPath);
          },
        );
      },
    );
  }

  Widget _buildGhostCard() {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.catalogCreate),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFBEC9C6).withValues(alpha: 0.8),
            width: 2,
            style: BorderStyle.solid,
          ),
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFECEEED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Color(0xFF0D5C56),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tambah Item Baru',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D5C56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(CatalogItem item, String? logoPath) {
    String? imageUrl;
    final nameLower = item.name.toLowerCase();
    if (nameLower.contains('coffee maker') || nameLower.contains('mesin kopi')) {
      imageUrl =
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAYRo5f6D7cezGrPWCQ8azi_JgrocwGAaPjErsSWBHHMVrIOl0sQOLFSzoukpuB0Bo24qzoV6GHmVsxkAZ2qPxY3Fh95nFpCxQJodXlhmQ48NrsJXwYGwVWmnvwhJ4OKgqbS18zhuLXuapTg6oFAMjW2h5hCf5GNRXmptpZlWzfIofgXo3iyH6n6jLWzvJLq0RWxWfpCn3Xn5eScP_2iFqZ_h10vEdal3owhpxWedXBJOXZ_vzNaRiK';
    } else if (nameLower.contains('beans') ||
        nameLower.contains('biji kopi') ||
        nameLower.contains('kopi roasted') ||
        nameLower.contains('arabica') ||
        nameLower.contains('robusta')) {
      imageUrl =
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBAnR4s6qrUz7K8v3e4CVx0jE4XTqSrp-DE993UDRCf6qeS3xns-0qVkZI3Dgre_fWgORI_IkU-Ta_KUs-nvL4sCgFTWqS14wccqMW6a_UvoDhCHY2Kt439GnWQHfHpvx7AXphwT8bKtjY_xG3ytYBoT3S0fZjHd6AByj-XUqybXoluEMuPiwy_DrloejdwIYsF3VlM5pj-Ge2uX5tYAqK2LuKeRzjQS2tt1WHUWSg3Bi4Ip2_HAZ7F';
    } else if (nameLower.contains('press')) {
      imageUrl =
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAyOrq4G3XULM6ZN06lo5YmlzQLVHlRMAkD1ln0Jg5EtTPd47X_9M-DZ3XNM5UQKm7F57jd5fNwyxoKU3cwSvTLn6DoFqR8ZAcHO5Ag5Mpe7eaqiNaeulB_aRat0y55_9LGuEpetXRQT0_SXF8g1SD5mIjadT0YqmyQL4nQhb1F1j1ySDE54uNNrVMkyRzjarvMQL11TX5kIj__bLQUUM6bOMe24QGhYQ6d1o6yDnJ_T56ivVlFS1Xa';
    }

    final isLowStock = item.isBarang && (item.stockQuantity ?? 0) <= 5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E3E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: Stack(
              children: [
                imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : (logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync())
                        ? Image.file(
                            File(logoPath),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFFECEEED),
                            width: double.infinity,
                            height: double.infinity,
                            child: const Icon(
                              Icons.storefront,
                              size: 40,
                              color: Color(0xFFBEC9C6),
                            ),
                          ),
                if (item.isBarang)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isLowStock
                            ? const Color(0xFFFFDAD6).withValues(alpha: 0.95)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.stockQuantity ?? 0} stok tersedia',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLowStock
                              ? const Color(0xFFBA1A1A)
                              : const Color(0xFF191C1C),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3F4947),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191C1C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CurrencyFormatter.format(item.sellingPrice),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D5C56),
                              ),
                            ),
                            if (item.wholesalePrice != null &&
                                item.wholesaleMinQuantity != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Grosir: ${CurrencyFormatter.format(item.wholesalePrice!)} (Min. ${item.wholesaleMinQuantity})',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0D5C56),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert,
                          size: 18,
                          color: Color(0xFF3F4947),
                        ),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            context.push('${AppRoutes.catalog}/edit/${item.id}');
                            return;
                          }
                          await ref
                              .read(katalogControllerProvider.notifier)
                              .toggleItemStatus(item);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit item'),
                          ),
                          PopupMenuItem<String>(
                            value: 'toggle',
                            child: Text(
                              item.isActive
                                  ? 'Nonaktifkan item'
                                  : 'Aktifkan item',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryView(List<CatalogItem> allItems) {
    final grouped = <String, List<CatalogItem>>{};
    for (final item in allItems) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    final categories = grouped.keys.toList()..sort();

    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'Belum ada kategori.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF3F4947),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 3 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final list = grouped[cat] ?? [];
            final productCount = list.where((item) => item.isBarang).length;
            final serviceCount = list.where((item) => item.isJasa).length;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE1E3E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFECEEED),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.grid_view,
                          color: Color(0xFF0D5C56),
                          size: 20,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECEEED),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${list.length} item',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3F4947),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF191C1C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$productCount produk • $serviceCount layanan',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF3F4947),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
