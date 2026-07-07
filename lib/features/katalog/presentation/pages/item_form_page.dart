import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
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

  String _itemType = 'barang';
  bool _isActive = true;
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
          ? int.parse(_stockController.text.trim())
          : null,
    );

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(catalogRepositoryProvider);
      if (_isEditMode) {
        await repository.updateItem(widget.itemId!, draft);
      } else {
        await repository.createItem(draft);
      }

      ref.invalidate(katalogControllerProvider);
      ref.invalidate(transaksiControllerProvider);

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
          _stockController.text = '${item.stockQuantity ?? 0}';
          _itemType = item.itemType;
          _isActive = item.isActive;
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

  Scaffold _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Item' : 'Tambah Barang')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _isEditMode ? 'Edit detail item' : 'Tambah item baru',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pisahkan barang dan jasa dengan jelas sebelum menyimpan item.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TypeChoiceCard(
                            title: 'Barang',
                            subtitle: 'Punya stok awal',
                            icon: Icons.inventory_2_outlined,
                            selected: _itemType == 'barang',
                            onTap: () {
                              setState(() {
                                _itemType = 'barang';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TypeChoiceCard(
                            title: 'Jasa',
                            subtitle: 'Tanpa stok',
                            icon: Icons.content_cut_rounded,
                            selected: _itemType == 'jasa',
                            onTap: () {
                              setState(() {
                                _itemType = 'jasa';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nama item',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Nama item wajib diisi.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _categoryController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Kategori wajib diisi.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _skuController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'SKU / kode item',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _unitController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: _itemType == 'barang'
                                ? 'Satuan'
                                : 'Label jasa',
                            hintText: _itemType == 'barang'
                                ? 'Pcs, Kg, Botol'
                                : 'Layanan',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Harga jual',
                            prefixText: 'Rp ',
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
                        ),
                        if (_itemType == 'barang') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _stockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stok awal',
                            ),
                            validator: (value) {
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed < 0) {
                                return 'Stok awal tidak boleh negatif.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: SwitchListTile.adaptive(
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Item aktif'),
                      subtitle: const Text(
                        'Item nonaktif tidak muncul di pemilihan transaksi.',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: const Icon(Icons.save_alt_rounded),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        _isSubmitting
                            ? 'Menyimpan item...'
                            : (_isEditMode
                                  ? 'Simpan Perubahan'
                                  : 'Simpan Item'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChoiceCard extends StatelessWidget {
  const _TypeChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}
