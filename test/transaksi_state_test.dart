import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/presentation/models/transaksi_state.dart';

void main() {
  const barang = TransaksiItem(
    id: 'barang-1',
    name: 'Kopi Literan',
    category: 'Minuman',
    itemType: 'barang',
    sellingPrice: 50000,
    stockQuantity: 12,
    unitLabel: 'Botol',
    isActive: true,
  );

  const jasa = TransaksiItem(
    id: 'jasa-1',
    name: 'Haircut',
    category: 'Layanan',
    itemType: 'jasa',
    sellingPrice: 35000,
    isActive: true,
    unitLabel: 'Layanan',
  );

  test('menghitung subtotal, diskon, pajak, dan total transaksi campuran', () {
    const state = TransaksiState(
      cartItems: [
        TransaksiCartItem(item: barang, quantity: 2, itemDiscountAmount: 10000),
        TransaksiCartItem(item: jasa, quantity: 1, itemDiscountAmount: 5000),
      ],
      orderDiscountAmount: 7000,
      taxAmount: 3000,
      paymentMethod: 'transfer',
    );

    expect(state.subtotalAmount, 135000);
    expect(state.itemDiscountAmount, 15000);
    expect(state.totalAmount, 116000);
    expect(state.canSubmit, isTrue);
  });

  test('pembayaran tunai harus cukup agar transaksi bisa disimpan', () {
    const baseState = TransaksiState(
      cartItems: [
        TransaksiCartItem(item: barang, quantity: 1, itemDiscountAmount: 0),
      ],
      paymentMethod: 'tunai',
      cashPaidAmount: 40000,
    );

    expect(baseState.totalAmount, 50000);
    expect(baseState.canSubmit, isFalse);

    const paidState = TransaksiState(
      cartItems: [
        TransaksiCartItem(item: barang, quantity: 1, itemDiscountAmount: 0),
      ],
      paymentMethod: 'tunai',
      cashPaidAmount: 60000,
    );

    expect(paidState.canSubmit, isTrue);
    expect(paidState.changeAmount, 10000);
  });
}
