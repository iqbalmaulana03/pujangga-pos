import 'package:flutter/material.dart';

class DetailStokPage extends StatelessWidget {
  const DetailStokPage({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Stok')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item: $itemId',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Placeholder detail stok untuk penyesuaian manual dan histori perubahan stok.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
