import 'package:flutter/material.dart';

class DetailTransaksiPage extends StatelessWidget {
  const DetailTransaksiPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
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
                    'Invoice $transactionId',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Placeholder detail transaksi untuk validasi route dan subflow riwayat.',
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
