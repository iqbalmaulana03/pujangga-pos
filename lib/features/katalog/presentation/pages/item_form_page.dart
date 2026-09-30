import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../../laporan/presentation/controllers/laporan_controller.dart';
import '../../../stok/presentation/controllers/stok_controller.dart';
import '../../../transaksi/presentation/controllers/transaksi_controller.dart';
import '../../domain/entities/catalog_item_draft.dart';
import '../controllers/katalog_controller.dart';

class ItemFormPage extends ConsumerStatefulWidget {
  const ItemFormPage({super.key, this.itemId});

  final String? itemId;

  @override
  ConsumerState<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends ConsumerState<ItemFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _skuController = TextEditingController();
  final _unitController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _costController = TextEditingController();
  final _wholesalePriceController = TextEditingController();
  final _wholesaleMinController = TextEditingController();

  String _itemType = 'barang';
  bool _isActive = true;
  bool _enableWholesale = false;
  bool _isSubmitting = false;
  bool _didHydrate = false;

  bool get _isEditMode => widget.itemId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _skuController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _costController.dispose();
    _wholesalePriceController.dispose();
    _wholesaleMinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final draft = CatalogItemDraft(
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
      itemType: _itemType,
      sellingPrice: double.parse(_priceController.text.trim()),
      isActive: _isActive,
      sku: _skuController.text.trim(),
      unitLabel: _unitController.text.trim(),
      stockQuantity: _itemType == 'barang'
          ? QuantityFormatter.parse(_stockController.text)!
          : null,
      costPrice: double.tryParse(_costController.text.trim()),
      wholesalePrice: _enableWholesale
          ? double.tryParse(_wholesalePriceController.text.trim())
          : null,
      wholesaleMinQuantity: _enableWholesale
          ? int.tryParse(_wholesaleMinController.text.trim())
          : null,
    );
    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_itemType == 'barang') {
        final costPrice = draft.costPrice ?? 0;
        final stockQty = draft.stockQuantity ?? 0;
        if (costPrice > 0 && stockQty > 0) {
          final metrics = await ref.read(capitalMetricsProvider.future);

          double oldStockValue = 0;
          if (_isEditMode) {
            final oldItem = await ref.read(
              catalogItemProvider(widget.itemId!).future,
            );
            if (oldItem != null &&
                oldItem.costPrice != null &&
                oldItem.stockQuantity != null) {
              oldStockValue = oldItem.costPrice! * oldItem.stockQuantity!;
            }
          }

          final newStockValue = costPrice * stockQty;
          final addedStockValue = newStockValue - oldStockValue;

          if (addedStockValue > metrics.currentCash) {
            if (mounted) {
              final formatter = CurrencyFormatter.format(metrics.currentCash);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Stok gagal disimpan. Sisa Kas Anda ($formatter) tidak mencukupi untuk nilai stok ini.',
                  ),
                ),
              );
              setState(() {
                _isSubmitting = false;
              });
            }
            return;
          }
        }
      }

      final repository = ref.read(catalogRepositoryProvider);
      if (_isEditMode) {
        await repository.updateItem(widget.itemId!, draft);
      } else {
        await repository.createItem(draft);
      }

      ref.invalidate(katalogControllerProvider);
      ref.invalidate(transaksiControllerProvider);
      ref.invalidate(stokControllerProvider);
      if (_isEditMode) {
        ref.invalidate(stockItemProvider(widget.itemId!));
        ref.invalidate(stockItemDetailProvider(widget.itemId!));
        ref.invalidate(stockMovementDetailProvider(widget.itemId!));
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Item berhasil diperbarui.'
                : 'Item baru berhasil disimpan.',
          ),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is AppException
          ? error.message
          : 'Item gagal disimpan. Coba lagi.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditMode) {
      return _buildScaffold(context);
    }

    final itemAsync = ref.watch(catalogItemProvider(widget.itemId!));
    return itemAsync.when(
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Item')),
            body: const Center(child: Text('Item tidak ditemukan.')),
          );
        }

        if (!_didHydrate) {
          _nameController.text = item.name;
          _categoryController.text = item.category;
          _skuController.text = item.sku ?? '';
          _unitController.text = item.unitLabel ?? '';
          _priceController.text = item.sellingPrice.toStringAsFixed(0);
          _stockController.text = QuantityFormatter.format(
            item.stockQuantity ?? 0,
          );
          _costController.text = item.costPrice != null
              ? item.costPrice!.toStringAsFixed(0)
              : '';
          _wholesalePriceController.text = item.wholesalePrice != null
              ? item.wholesalePrice!.toStringAsFixed(0)
              : '';
          _wholesaleMinController.text = item.wholesaleMinQuantity != null
              ? '${item.wholesaleMinQuantity}'
              : '';
          _itemType = item.itemType;
          _isActive = item.isActive;
          _enableWholesale = item.wholesalePrice != null;
          _didHydrate = true;
        }

        return _buildScaffold(context);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Edit Item')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  void _adjustStock(int amount) {
    final current = QuantityFormatter.parse(_stockController.text) ?? 0;
    final next = (current + amount).clamp(0, 999999);
    setState(() {
      _stockController.text = QuantityFormatter.format(next);
    });
  }

  Scaffold _buildScaffold(BuildContext context) {
    final isProduct = _itemType == 'barang';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0D5C56)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditMode ? 'Edit Item' : 'Tambah Barang',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D5C56),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFBEC9C6)),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // General Info Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFBEC9C6,
                            ).withValues(alpha: 0.3),
                          ),
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
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF3F4947),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Informasi Umum',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3F4947),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'NAMA BARANG',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3F4947),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: 'e.g. Kopi Susu Aren',
                                filled: true,
                                fillColor: const Color(0xFFF2F4F2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0D5C56),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Nama item wajib diisi.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'KATEGORI',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3F4947),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _categoryController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: 'Pilih atau ketik kategori',
                                filled: true,
                                fillColor: const Color(0xFFF2F4F2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0D5C56),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Kategori wajib diisi.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildCategorySuggestions(),
                            const SizedBox(height: 20),
                            const Text(
                              'TIPE BARANG',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3F4947),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 48,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6E9E7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _itemType = 'barang';
                                        });
                                      },
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isProduct
                                              ? const Color(0xFF0D5C56)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.inventory_2,
                                              size: 18,
                                              color: isProduct
                                                  ? Colors.white
                                                  : const Color(0xFF3F4947),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Produk',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isProduct
                                                    ? Colors.white
                                                    : const Color(0xFF3F4947),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _itemType = 'jasa';
                                        });
                                      },
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: !isProduct
                                              ? const Color(0xFF0D5C56)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.design_services,
                                              size: 18,
                                              color: !isProduct
                                                  ? Colors.white
                                                  : const Color(0xFF3F4947),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Layanan',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: !isProduct
                                                    ? Colors.white
                                                    : const Color(0xFF3F4947),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Pricing & Unit Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFBEC9C6,
                            ).withValues(alpha: 0.3),
                          ),
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
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.payments_outlined,
                                  color: Color(0xFF3F4947),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Harga & Satuan',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3F4947),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'HARGA JUAL',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3F4947),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF191C1C),
                              ),
                              decoration: InputDecoration(
                                prefixIcon: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    CurrencyFormatter.symbol,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D5C56),
                                    ),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 0,
                                  minHeight: 0,
                                ),
                                hintText: '0',
                                filled: true,
                                fillColor: const Color(0xFFF2F4F2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0D5C56),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final parsed = double.tryParse(
                                  (value ?? '').trim(),
                                );
                                if (parsed == null || parsed <= 0) {
                                  return 'Harga jual harus lebih dari 0.';
                                }
                                return null;
                              },
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isProduct
                                  ? 'HARGA MODAL'
                                  : 'BIAYA DASAR (OPSIONAL)',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3F4947),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _costController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF191C1C),
                              ),
                              decoration: InputDecoration(
                                prefixIcon: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    CurrencyFormatter.symbol,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D5C56),
                                    ),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 0,
                                  minHeight: 0,
                                ),
                                hintText: '0',
                                filled: true,
                                fillColor: const Color(0xFFF2F4F2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0D5C56),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Digunakan untuk perhitungan margin',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF3F4947),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'SKU (OPSIONAL)',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3F4947),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _skuController,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          hintText: 'ABC-123',
                                          filled: true,
                                          fillColor: const Color(0xFFF2F4F2),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF0D5C56),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isProduct ? 'SATUAN' : 'LABEL JASA',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3F4947),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _unitController,
                                        textInputAction: TextInputAction.done,
                                        decoration: InputDecoration(
                                          hintText: isProduct
                                              ? 'pcs'
                                              : 'layanan',
                                          filled: true,
                                          fillColor: const Color(0xFFF2F4F2),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF0D5C56),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Wholesale Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFBEC9C6,
                            ).withValues(alpha: 0.3),
                          ),
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
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.local_offer_outlined,
                                      color: Color(0xFF3F4947),
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Harga Grosir',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3F4947),
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _enableWholesale,
                                  onChanged: (val) {
                                    setState(() {
                                      _enableWholesale = val;
                                    });
                                  },
                                  activeTrackColor: const Color(
                                    0xFF0D5C56,
                                  ).withValues(alpha: 0.5),
                                  activeThumbColor: const Color(0xFF0D5C56),
                                ),
                              ],
                            ),
                            if (_enableWholesale) ...[
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'HARGA GROSIR',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3F4947),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _wholesalePriceController,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF191C1C),
                                          ),
                                          decoration: InputDecoration(
                                            prefixIcon: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                              child: Text(
                                                CurrencyFormatter.symbol,
                                                style: const TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0D5C56),
                                                ),
                                              ),
                                            ),
                                            prefixIconConstraints:
                                                const BoxConstraints(
                                                  minWidth: 0,
                                                  minHeight: 0,
                                                ),
                                            hintText: '0',
                                            filled: true,
                                            fillColor: const Color(0xFFF2F4F2),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Color(0xFF0D5C56),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (!_enableWholesale) return null;
                                            final parsed = double.tryParse(
                                              (value ?? '').trim(),
                                            );
                                            if (parsed == null || parsed <= 0) {
                                              return 'Tidak valid';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'MIN QTY',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3F4947),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _wholesaleMinController,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF191C1C),
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '2',
                                            filled: true,
                                            fillColor: const Color(0xFFF2F4F2),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Color(0xFF0D5C56),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (!_enableWholesale) return null;
                                            final parsed = int.tryParse(
                                              (value ?? '').trim(),
                                            );
                                            if (parsed == null || parsed <= 1) {
                                              return '> 1';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Stock Management Section (Disabled/Dimmed when Layanan)
                      Opacity(
                        opacity: isProduct ? 1.0 : 0.4,
                        child: IgnorePointer(
                          ignoring: !isProduct,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFECEEED,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF0D5C56,
                                ).withValues(alpha: 0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(
                                          Icons.warehouse_outlined,
                                          color: Color(0xFF0D5C56),
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Manajemen Stok',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0D5C56),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D5C56),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'DIPANTAU',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF8ED2CA),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Center(
                                  child: Text(
                                    'STOK AWAL',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D5C56),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _adjustStock(-1),
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFECEEED),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.remove,
                                          color: Color(0xFF0D5C56),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        controller: _stockController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF191C1C),
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        validator: (value) {
                                          if (!isProduct) return null;
                                          final parsed =
                                              QuantityFormatter.parse(value);
                                          if (parsed == null || parsed < 0) {
                                            return 'Harus >= 0.';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () => _adjustStock(1),
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFECEEED),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Color(0xFF0D5C56),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Center(
                                  child: Text(
                                    'Stok awal dan perubahan stok dicatat dalam log inventaris.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF3F4947),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Status Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFFBEC9C6,
                            ).withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Status Aktif',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF191C1C),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tampilkan barang untuk transaksi',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Color(0xFF3F4947),
                                  ),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: _isActive,
                              activeThumbColor: const Color(0xFF0D5C56),
                              onChanged: (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Storefront Low Opacity Decoration
                      const Opacity(
                        opacity: 0.1,
                        child: Center(
                          child: Icon(
                            Icons.storefront,
                            size: 80,
                            color: Color(0xFF0D5C56),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Sticky Bottom Actions Footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                border: const Border(
                  top: BorderSide(color: Color(0xFFE1E3E1), width: 1),
                ),
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: const Icon(Icons.save, size: 20),
                    label: Text(
                      _isSubmitting
                          ? 'Menyimpan...'
                          : (_isEditMode
                                ? 'Simpan Perubahan'
                                : 'Simpan Barang'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySuggestions() {
    final categories = const ['Coffee', 'Non-Coffee', 'Pastry', 'Merchandise'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cat in categories)
          GestureDetector(
            onTap: () {
              setState(() {
                _categoryController.text = cat;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _categoryController.text == cat
                      ? const Color(0xFF0D5C56)
                      : const Color(0xFFBEC9C6),
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: _categoryController.text == cat
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _categoryController.text == cat
                      ? const Color(0xFF0D5C56)
                      : const Color(0xFF3F4947),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
