import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../controllers/tambah_pengeluaran_controller.dart';
import '../../../karyawan/presentation/controllers/employee_controller.dart';

class TambahPengeluaranPage extends ConsumerStatefulWidget {
  const TambahPengeluaranPage({super.key});

  @override
  ConsumerState<TambahPengeluaranPage> createState() =>
      _TambahPengeluaranPageState();
}

class _TambahPengeluaranPageState extends ConsumerState<TambahPengeluaranPage> {
  final _formKey = GlobalKey<FormState>();
  final _nominalController = TextEditingController();
  final _catatanController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedKategori = 'Operasional';
  int? _employeeId;

  final List<String> _kategoriOptions = [
    'Operasional',
    'Bahan Baku',
    'Gaji Karyawan',
    'Lain-lain',
  ];

  @override
  void dispose() {
    _nominalController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  void _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final nominal = _parseNominal(_nominalController.text);
    if (nominal == null || nominal <= 0) return;

    final catatan = _catatanController.text.trim();

    await ref
        .read(tambahPengeluaranControllerProvider.notifier)
        .simpanPengeluaran(
          nominal: nominal,
          kategori: _selectedKategori,
          tanggal: _selectedDate,
          catatan: catatan.isEmpty ? null : catatan,
          employeeId: _employeeId,
        );

    if (mounted && ref.read(tambahPengeluaranControllerProvider).hasError) {
      final error = ref.read(tambahPengeluaranControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is StateError ? error.message.toString() : 'Pengeluaran gagal disimpan. Silakan coba lagi.'),
      ));
    }
    if (mounted && !ref.read(tambahPengeluaranControllerProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengeluaran berhasil disimpan')),
      );
      context.pop();
    }
  }

  double? _parseNominal(String? value) {
    final normalized = value?.trim().replaceAll(',', '.') ?? '';
    return double.tryParse(normalized);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0D5C56)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tambahPengeluaranControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text(
          'Tambah Pengeluaran',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Color(0xFF191C1C),
          ),
        ),
        backgroundColor: const Color(0xFFF8FAF8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF191C1C)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Tanggal
            const Text(
              'Tanggal',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F4947),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFBEC9C6)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF191C1C),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: Color(0xFF3F4947),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Kategori
            const Text(
              'Kategori',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F4947),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFBEC9C6)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedKategori,
                  isExpanded: true,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Color(0xFF191C1C),
                  ),
                  items: _kategoriOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedKategori = val;
                        _employeeId = null;
                        _nominalController.clear();
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Nominal
            if (_selectedKategori == 'Gaji Karyawan') ...[
              ref.watch(activeEmployeesProvider).when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Karyawan gagal dimuat.'),
                data: (employees) {
                  final salaried = employees.where((e) => !e.isCommission).toList();
                  return DropdownButtonFormField<int>(
                    initialValue: _employeeId,
                    decoration: const InputDecoration(labelText: 'Karyawan', border: OutlineInputBorder()),
                    hint: Text(salaried.isEmpty ? 'Belum ada karyawan bergaji bulanan' : 'Pilih karyawan'),
                    items: salaried.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                    validator: (value) => value == null ? 'Pilih karyawan bergaji bulanan' : null,
                    onChanged: isLoading ? null : (id) => setState(() {
                      _employeeId = id;
                      final employee = salaried.firstWhere((e) => e.id == id);
                      _nominalController.text = employee.monthlySalary!.toStringAsFixed(0);
                    }),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            const Text(
              'Nominal',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F4947),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nominalController,
              readOnly: _selectedKategori == 'Gaji Karyawan',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF191C1C),
              ),
              decoration: InputDecoration(
                prefixText: '${CurrencyFormatter.symbol} ',
                prefixStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF191C1C),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFBEC9C6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFBEC9C6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF0D5C56)),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nominal tidak boleh kosong';
                }
                final numVal = _parseNominal(value);
                if (numVal == null || numVal <= 0) return 'Nominal tidak valid';
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 24),

            // Catatan
            const Text(
              'Catatan',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F4947),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _catatanController,
              maxLines: 3,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF191C1C),
              ),
              decoration: InputDecoration(
                hintText: 'Tambah catatan (opsional)',
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFFBEC9C6),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFBEC9C6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFBEC9C6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF0D5C56)),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: isLoading ? null : _onSave,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Simpan Pengeluaran',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
