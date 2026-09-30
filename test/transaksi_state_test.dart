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

  test('menghitung penjualan dan sisa stok dengan kuantitas pecahan', () {
    const ikan = TransaksiItem(
      id: 'ikan-kg',
      name: 'Ikan segar',
      category: 'Ikan',
      itemType: 'barang',
      sellingPrice: 80000,
      stockQuantity: 1.5,
      unitLabel: 'kg',
      isActive: true,
    );
    const cartItem = TransaksiCartItem(
      item: ikan,
      quantity: 0.25,
      itemDiscountAmount: 0,
    );
    const state = TransaksiState(cartItems: [cartItem], paymentMethod: 'qris');

    expect(cartItem.lineSubtotal, 20000);
    expect(state.subtotalAmount, 20000);
    expect(ikan.stockQuantity! - cartItem.quantity, 1.25);
  });

  test(
    'menghitung harga grosir secara otomatis ketika kuantitas memenuhi syarat',
    () {
      const barangGrosir = TransaksiItem(
        id: 'barang-grosir',
        name: 'Pensil',
        category: 'ATK',
        itemType: 'barang',
        sellingPrice: 5000,
        wholesalePrice: 4000,
        wholesaleMinQuantity: 12,
        isActive: true,
      );

      // Beli 10 (belum grosir) -> 10 * 5000 = 50000
      const stateRetail = TransaksiState(
        cartItems: [
          TransaksiCartItem(
            item: barangGrosir,
            quantity: 10,
            itemDiscountAmount: 0,
          ),
        ],
        paymentMethod: 'tunai',
        cashPaidAmount: 50000,
      );

      expect(stateRetail.subtotalAmount, 50000);

      // Beli 12 (sudah grosir) -> 12 * 4000 = 48000
      const stateGrosir = TransaksiState(
        cartItems: [
          TransaksiCartItem(
            item: barangGrosir,
            quantity: 12,
            itemDiscountAmount: 0,
          ),
        ],
        paymentMethod: 'tunai',
        cashPaidAmount: 50000,
      );

      expect(stateGrosir.subtotalAmount, 48000);
    },
  );
}
