import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../domain/services/receipt_text_formatter.dart';
import 'transaksi_controller.dart';

final receiptShareLauncherProvider =
    Provider<Future<ShareResult> Function(ShareParams)>(
      (ref) => SharePlus.instance.share,
    );

final receiptShareControllerProvider =
    NotifierProvider<ReceiptShareController, bool>(ReceiptShareController.new);

class ReceiptShareController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<ShareResult?> share(String invoiceNumber) async {
    if (state) return null;
    state = true;
    try {
      final repository = ref.read(transactionRepositoryProvider);
      final launcher = ref.read(receiptShareLauncherProvider);
      final receipt = await repository.getReceiptByInvoice(invoiceNumber);
      if (receipt == null) throw StateError('Receipt not found');
      final profile = await ref.read(businessProfileProvider.future);
      return await launcher(
        ShareParams(
          text: const ReceiptTextFormatter().format(receipt, profile),
          subject: 'Struk ${receipt.invoiceNumber}',
        ),
      );
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
