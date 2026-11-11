import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../../setup_usaha/domain/entities/business_profile.dart';
import '../entities/transaksi_receipt.dart';

/// Customer-facing fields only. Never serialize the receipt/profile objects.
class ReceiptTextFormatter {
  const ReceiptTextFormatter();

  String format(TransaksiReceipt receipt, BusinessProfile? profile) {
    final lines = <String>[
      profile?.businessName ?? 'Struk Pembayaran',
      if (profile?.address?.trim().isNotEmpty ?? false) profile!.address!,
      if (profile?.contactNumber?.trim().isNotEmpty ?? false)
        profile!.contactNumber!,
      '',
      'Invoice: ${receipt.invoiceNumber}',
      'Waktu: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(receipt.createdAt.toLocal())}',
      if (receipt.status != 'completed') 'Status: ${receipt.status}',
      '',
    ];
    for (final line in receipt.items) {
      lines.addAll([
        line.item.name,
        '${QuantityFormatter.format(line.quantity)}${line.item.unitLabel == null ? '' : ' ${line.item.unitLabel}'} x ${CurrencyFormatter.format(line.unitPrice)}',
        if (line.itemDiscountAmount != 0)
          'Diskon item: -${CurrencyFormatter.format(line.itemDiscountAmount)}',
        'Jumlah: ${CurrencyFormatter.format(line.lineTotal)}',
      ]);
    }
    lines.addAll([
      '',
      'Subtotal: ${CurrencyFormatter.format(receipt.subtotalAmount)}',
      'Diskon item: -${CurrencyFormatter.format(receipt.itemDiscountAmount)}',
      'Diskon transaksi: -${CurrencyFormatter.format(receipt.orderDiscountAmount)}',
      'Pajak: ${CurrencyFormatter.format(receipt.taxAmount)}',
      'Total: ${CurrencyFormatter.format(receipt.totalAmount)}',
      'Metode pembayaran: ${paymentLabel(receipt.paymentMethod)}',
      if (receipt.paymentMethod == 'tunai') ...[
        if (receipt.cashPaidAmount != null)
          'Bayar: ${CurrencyFormatter.format(receipt.cashPaidAmount!)}',
        'Kembalian: ${CurrencyFormatter.format(receipt.changeAmount)}',
      ],
      '',
      'Terima kasih.',
    ]);
    return lines.join('\n');
  }

  static String paymentLabel(String value) => switch (value) {
    'tunai' => 'Tunai',
    'transfer' => 'Transfer',
    'qris' => 'QRIS',
    'ewallet' => 'E-Wallet',
    'kartu' => 'Kartu',
    _ => value.toUpperCase(),
  };
}
