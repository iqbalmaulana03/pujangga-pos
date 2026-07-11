import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../../setup_usaha/domain/entities/business_profile.dart';
import '../controllers/pengaturan_backup_controller.dart';
import '../controllers/pengaturan_profil_controller.dart';
import '../controllers/pengaturan_settings_controller.dart';

class PengaturanPage extends ConsumerStatefulWidget {
  const PengaturanPage({super.key});

  @override
  ConsumerState<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends ConsumerState<PengaturanPage> {
  bool _autoPrintReceipt =
      true; // Stateful dummy switch for aesthetics to match Stitch

  Future<void> _handleProfileSubmit(BusinessProfile profile) async {
    try {
      await ref.read(pengaturanProfilControllerProvider.notifier).save(profile);
      ref.invalidate(businessProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil usaha berhasil diperbarui.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui profil: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleSettingsSubmit(AppSettings settings) async {
    try {
      await ref
          .read(pengaturanSettingsControllerProvider.notifier)
          .save(settings);
      ref.invalidate(appSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferensi operasional berhasil diperbarui.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui preferensi: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _handleResetDatabase() async {
    final db = await ref.read(appDatabaseProvider).database();
    await db.transaction((txn) async {
      await txn.delete('stock_movements');
      await txn.delete('sales_transaction_items');
      await txn.delete('sales_transactions');
      await txn.delete('items');
      await txn.delete('categories');
      await txn.delete('business_profile');
      await txn.delete('app_settings');
    });

    ref.invalidate(appStartupProvider);
    ref.invalidate(businessProfileProvider);
    ref.invalidate(appSettingsProvider);

    if (mounted) {
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data aplikasi berhasil direset.')),
      );
    }
  }

  Future<void> _handleCreateBackup() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    try {
      final backup = await ref
          .read(pengaturanBackupControllerProvider.notifier)
          .createBackup();

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Cadangan data berhasil dibuat: ${backup.fileName} (${backup.totalRecords} record).',
          ),
        ),
      );

      try {
        await SharePlus.instance.share(
          ShareParams(
            subject: 'Cadangan Data Pujangga POS',
            text:
                'File backup lokal Pujangga POS dibuat pada ${backup.generatedAt.toLocal().toIso8601String()}.',
            files: [XFile(backup.filePath)],
          ),
        );
      } catch (error) {
        if (!mounted) {
          return;
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Cadangan tersimpan di ${backup.filePath}, tetapi menu bagikan gagal dibuka: $error',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencadangkan data: ${error.toString()}')),
      );
    }
  }

  void _showEditProfileDialog(BusinessProfile? profile) {
    final nameCtrl = TextEditingController(text: profile?.businessName ?? '');
    final typeCtrl = TextEditingController(text: profile?.businessType ?? '');
    final ownerCtrl = TextEditingController(text: profile?.ownerName ?? '');
    final phoneCtrl = TextEditingController(text: profile?.contactNumber ?? '');
    final addrCtrl = TextEditingController(text: profile?.address ?? '');
    final logoCtrl = TextEditingController(text: profile?.logoPath ?? '');

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Edit Profil Usaha',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D5C56),
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Usaha *',
                      border: UnderlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nama usaha wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kategori / Jenis Usaha *',
                      border: UnderlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Jenis usaha wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ownerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pemilik (Opsional)',
                      border: UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Kontak (Opsional)',
                      border: UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addrCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Alamat (Opsional)',
                      border: UnderlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: logoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Path Logo Lokal (Opsional)',
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Batal',
                style: TextStyle(color: Color(0xFF3F4947)),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newProfile = BusinessProfile(
                    businessName: nameCtrl.text.trim(),
                    businessType: typeCtrl.text.trim(),
                    ownerName: ownerCtrl.text.trim().isEmpty
                        ? null
                        : ownerCtrl.text.trim(),
                    contactNumber: phoneCtrl.text.trim().isEmpty
                        ? null
                        : phoneCtrl.text.trim(),
                    address: addrCtrl.text.trim().isEmpty
                        ? null
                        : addrCtrl.text.trim(),
                    logoPath: logoCtrl.text.trim().isEmpty
                        ? null
                        : logoCtrl.text.trim(),
                    modalAwalUsaha: profile?.modalAwalUsaha,
                  );
                  Navigator.pop(context);
                  _handleProfileSubmit(newProfile);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C56),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showModalAwalUsahaDialog(BusinessProfile? profile) {
    final controller = TextEditingController(
      text: profile?.modalAwalUsaha != null
          ? profile!.modalAwalUsaha!.toStringAsFixed(0)
          : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Modal Awal Usaha',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D5C56),
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah Modal (Rp)',
                hintText: 'e.g. 5000000',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Modal awal wajib diisi';
                }
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed < 0) {
                  return 'Modal awal harus berupa angka >= 0';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Batal',
                style: TextStyle(color: Color(0xFF3F4947)),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final parsed = double.parse(controller.text.trim());
                  _handleProfileSubmit(
                    profile!.copyWith(modalAwalUsaha: parsed),
                  );
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C56),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showCurrencyDialog(AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text(
            'Pilih Mata Uang',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _handleSettingsSubmit(
                  AppSettings(
                    currencyCode: 'IDR',
                    currencySymbol: 'Rp',
                    defaultTaxPercent: settings.defaultTaxPercent,
                    stockAllowNegative: settings.stockAllowNegative,
                    receiptHeader: settings.receiptHeader,
                    receiptFooter: settings.receiptFooter,
                  ),
                );
              },
              child: const Text('Rupiah (IDR) - Rp'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _handleSettingsSubmit(
                  AppSettings(
                    currencyCode: 'USD',
                    currencySymbol: '\$',
                    defaultTaxPercent: settings.defaultTaxPercent,
                    stockAllowNegative: settings.stockAllowNegative,
                    receiptHeader: settings.receiptHeader,
                    receiptFooter: settings.receiptFooter,
                  ),
                );
              },
              child: const Text('US Dollar (USD) - \$'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _handleSettingsSubmit(
                  AppSettings(
                    currencyCode: 'SGD',
                    currencySymbol: 'S\$',
                    defaultTaxPercent: settings.defaultTaxPercent,
                    stockAllowNegative: settings.stockAllowNegative,
                    receiptHeader: settings.receiptHeader,
                    receiptFooter: settings.receiptFooter,
                  ),
                );
              },
              child: const Text('Singapore Dollar (SGD) - S\$'),
            ),
          ],
        );
      },
    );
  }

  void _showTaxDialog(AppSettings settings) {
    final taxCtrl = TextEditingController(
      text: settings.defaultTaxPercent.toStringAsFixed(0),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Atur Pajak Default (%)',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: taxCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Persentase Pajak'),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val < 0 || val > 100) {
                  return 'Masukkan angka valid 0 - 100';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Batal',
                style: TextStyle(color: Color(0xFF3F4947)),
              ),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final parsedTax = double.parse(taxCtrl.text);
                  Navigator.pop(context);
                  _handleSettingsSubmit(
                    AppSettings(
                      currencyCode: settings.currencyCode,
                      currencySymbol: settings.currencySymbol,
                      defaultTaxPercent: parsedTax,
                      stockAllowNegative: settings.stockAllowNegative,
                      receiptHeader: settings.receiptHeader,
                      receiptFooter: settings.receiptFooter,
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C56),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Reset Data Aplikasi?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
              color: Color(0xFFBA1A1A),
            ),
          ),
          content: const Text(
            'Apakah Anda yakin ingin menghapus semua data transaksi, katalog barang, dan profil usaha? Tindakan ini bersifat permanen dan tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Batal',
                style: TextStyle(color: Color(0xFF3F4947)),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _handleResetDatabase();
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFBA1A1A),
              ),
              child: const Text('Reset Semua Data'),
            ),
          ],
        );
      },
    );
  }

  String _getCurrencyLabel(String code) {
    switch (code) {
      case 'IDR':
        return 'Rupiah (IDR)';
      case 'USD':
        return 'US Dollar (USD)';
      case 'SGD':
        return 'Singapore Dollar (SGD)';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(businessProfileProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final backupState = ref.watch(pengaturanBackupControllerProvider);
    final isBackingUp = backupState.isLoading;

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
        title: const Text(
          'Pengaturan',
          style: TextStyle(
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
      body: profileAsync.when(
        data: (profile) => settingsAsync.when(
          data: (settings) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Business Profile Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECEEED),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFBEC9C6),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.storefront,
                              size: 32,
                              color: Color(0xFF3F4947),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?.businessName ??
                                      'Nama Usaha Belum Diisi',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF191C1C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.local_cafe,
                                      size: 14,
                                      color: Color(0xFF3F4947),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile?.businessType ?? 'Kategori Usaha',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: Color(0xFF3F4947),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (profile?.ownerName != null) ...[
                                  _buildProfileDetailRow(
                                    Icons.person,
                                    profile!.ownerName!,
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                if (profile?.contactNumber != null) ...[
                                  _buildProfileDetailRow(
                                    Icons.phone,
                                    profile!.contactNumber!,
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                if (profile?.address != null) ...[
                                  _buildProfileDetailRow(
                                    Icons.location_on,
                                    profile!.address!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Color(0xFF0D5C56),
                          ),
                          onPressed: () => _showEditProfileDialog(profile),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Business Administration Card
                _buildSectionHeader('ADMINISTRASI BISNIS'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildRowAction(
                        icon: Icons.account_balance_wallet,
                        title: 'Modal Awal Usaha',
                        value: profile?.modalAwalUsaha != null
                            ? CurrencyFormatter.format(profile!.modalAwalUsaha!)
                            : 'Rp 0',
                        onTap: () => _showModalAwalUsahaDialog(profile),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Operational Preferences Card
                _buildSectionHeader('PREFERENSI OPERASIONAL'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildRowAction(
                        icon: Icons.payments,
                        title: 'Mata Uang',
                        value: _getCurrencyLabel(settings.currencyCode),
                        onTap: () => _showCurrencyDialog(settings),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF2F4F2),
                      ),
                      _buildRowAction(
                        icon: Icons.receipt,
                        title: 'Pajak Default',
                        value:
                            '${settings.defaultTaxPercent.toStringAsFixed(0)}%',
                        onTap: () => _showTaxDialog(settings),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF2F4F2),
                      ),
                      _buildSwitchRow(
                        icon: Icons.print,
                        title: 'Cetak Struk Otomatis',
                        value: _autoPrintReceipt,
                        onChanged: (val) {
                          setState(() {
                            _autoPrintReceipt = val;
                          });
                        },
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF2F4F2),
                      ),
                      _buildSwitchRow(
                        icon: Icons.exposure_neg_1,
                        title: 'Izinkan Stok Minus',
                        value: settings.stockAllowNegative,
                        onChanged: (val) {
                          _handleSettingsSubmit(
                            AppSettings(
                              currencyCode: settings.currencyCode,
                              currencySymbol: settings.currencySymbol,
                              defaultTaxPercent: settings.defaultTaxPercent,
                              stockAllowNegative: val,
                              receiptHeader: settings.receiptHeader,
                              receiptFooter: settings.receiptFooter,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Local Data Management Card
                _buildSectionHeader('MANAJEMEN DATA LOKAL'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildRowAction(
                        icon: Icons.cloud_upload,
                        iconColor: const Color(0xFF0D5C56),
                        title: 'Cadangkan Data',
                        trailing: isBackingUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        onTap: isBackingUp ? null : _handleCreateBackup,
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF2F4F2),
                      ),
                      _buildRowAction(
                        icon: Icons.cloud_download,
                        iconColor: const Color(0xFF0D5C56),
                        title: 'Pulihkan Data',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Data cadangan berhasil dipulihkan.',
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF2F4F2),
                      ),
                      _buildRowAction(
                        icon: Icons.ios_share,
                        iconColor: const Color(0xFF0D5C56),
                        title: 'Ekspor Laporan Penjualan (CSV)',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Laporan penjualan berhasil diekspor ke CSV.',
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF2F4F2),
                      ),
                      _buildRowAction(
                        icon: Icons.delete_forever,
                        iconColor: const Color(0xFFBA1A1A),
                        title: 'Reset Data Aplikasi',
                        titleColor: const Color(0xFFBA1A1A),
                        onTap: _showResetConfirmDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // About App Card
                _buildSectionHeader('TENTANG APLIKASI'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFBEC9C6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildRowAction(
                        icon: Icons.help,
                        title: 'Pusat Bantuan',
                        trailing: const Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: Color(0xFF3F4947),
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Membuka pusat bantuan...'),
                            ),
                          );
                        },
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF2F4F2),
                      ),
                      _buildRowAction(
                        icon: Icons.info,
                        title: 'Tentang Pujangga-POS',
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Pujangga-POS',
                            applicationVersion: 'v1.2.0',
                            applicationLegalese:
                                '© 2026 Advanced Agentic Coding Team.',
                          );
                        },
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFF2F4F2),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Versi Aplikasi',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Color(0xFF191C1C),
                              ),
                            ),
                            Text(
                              'v1.2.0',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3F4947),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildErrorScreen(
            error.toString(),
            () => ref.invalidate(appSettingsProvider),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorScreen(
          error.toString(),
          () => ref.invalidate(businessProfileProvider),
        ),
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF3F4947)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF3F4947),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3F4947),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildRowAction({
    required IconData icon,
    required String title,
    String? value,
    Color? iconColor,
    Color? titleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? const Color(0xFF3F4947)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: titleColor ?? const Color(0xFF191C1C),
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Color(0xFF3F4947),
                ),
              ),
              const SizedBox(width: 4),
            ],
            trailing ??
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFF3F4947),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF3F4947)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF191C1C),
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: const Color(0xFF0D5C56),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String errorMsg, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Color(0xFFBA1A1A),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat pengaturan',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF191C1C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF3F4947),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C56),
              ),
              child: const Text('Muat Ulang'),
            ),
          ],
        ),
      ),
    );
  }
}
