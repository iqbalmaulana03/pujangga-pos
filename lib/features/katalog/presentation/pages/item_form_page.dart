import 'package:flutter/material.dart';

class ItemFormPage extends StatelessWidget {
  const ItemFormPage({super.key, this.itemId});

  final String? itemId;

  @override
  Widget build(BuildContext context) {
    final isEditMode = itemId != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditMode ? 'Edit Item' : 'Tambah Item')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            isEditMode
                ? 'Placeholder form edit item untuk ID: $itemId'
                : 'Placeholder form tambah item sesuai alur canonical Tambah Barang (Refined).',
          ),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Nama item')),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Kategori')),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(labelText: 'Harga jual'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Simpan Placeholder'),
          ),
        ],
      ),
    );
  }
}
