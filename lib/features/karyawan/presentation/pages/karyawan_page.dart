import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/employee_controller.dart';
import '../../domain/entities/employee.dart';

class KaryawanPage extends ConsumerWidget {
  const KaryawanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(employeesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(title: const Text('Karyawan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref),
        label: const Text('Tambah'),
        icon: const Icon(Icons.person_add),
        backgroundColor: const Color(0xFF0D5C56),
        foregroundColor: Colors.white,
      ),
      body: employees.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat karyawan: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Belum ada data karyawan.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _EmployeeTile(
                  employee: items[index],
                  onTap: () => _showForm(context, ref, items[index]),
                ),
              ),
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, [
    Employee? employee,
  ]) async {
    final name = TextEditingController(text: employee?.name);
    final value = TextEditingController(
      text: employee?.isCommission == true
          ? '${employee?.commissionPercent ?? ''}'
          : '${employee?.monthlySalary ?? ''}',
    );
    var type = employee?.compensationType ?? 'commission';
    var scope = employee?.commissionScope ?? 'all';
    var active = employee?.isActive ?? true;
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(employee == null ? 'Tambah Karyawan' : 'Edit Karyawan'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nama karyawan',
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Skema kompensasi',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'commission',
                        child: Text('Komisi transaksi'),
                      ),
                      DropdownMenuItem(
                        value: 'monthly_salary',
                        child: Text('Gaji bulanan'),
                      ),
                    ],
                    onChanged: (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: type == 'commission'
                          ? 'Persentase komisi (%)'
                          : 'Gaji bulanan',
                    ),
                    validator: (v) {
                      final n = double.tryParse(v!.replaceAll(',', '.'));
                      if (n == null ||
                          !n.isFinite ||
                          n <= 0 ||
                          (type == 'commission' && n > 100)) {
                        return 'Nilai tidak valid';
                      }
                      return null;
                    },
                  ),
                  if (type == 'commission') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: scope,
                      decoration: const InputDecoration(
                        labelText: 'Cakupan komisi',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Barang dan jasa'),
                        ),
                        DropdownMenuItem(
                          value: 'service',
                          child: Text('Jasa saja'),
                        ),
                        DropdownMenuItem(
                          value: 'product',
                          child: Text('Barang saja'),
                        ),
                      ],
                      onChanged: (v) => setState(() => scope = v!),
                    ),
                    const Text(
                      'Dihitung setelah diskon, tanpa pajak.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  SwitchListTile(
                    title: const Text('Karyawan aktif'),
                    value: active,
                    onChanged: (v) => setState(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final n = double.parse(value.text.replaceAll(',', '.'));
                await ref
                    .read(employeeControllerProvider.notifier)
                    .save(
                      id: employee?.id,
                      name: name.text,
                      isActive: active,
                      compensationType: type,
                      commissionScope: scope,
                      commissionPercent: type == 'commission' ? n : null,
                      monthlySalary: type == 'monthly_salary' ? n : null,
                      effectiveFrom: employee?.effectiveFrom ?? DateTime.now(),
                    );
                if (ref.read(employeeControllerProvider).hasError) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Karyawan gagal disimpan. Periksa data lalu coba lagi.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                if (context.mounted) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  await Future<void>.delayed(const Duration(milliseconds: 100));
                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  ref.invalidate(employeesProvider);
                  ref.invalidate(activeEmployeesProvider);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    value.dispose();
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee, required this.onTap});
  final Employee employee;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(
          employee.name.isEmpty ? '?' : employee.name[0].toUpperCase(),
        ),
      ),
      title: Text(employee.name),
      subtitle: Text(
        employee.isCommission
            ? 'Komisi ${employee.commissionPercent?.toStringAsFixed(1)}% · ${employee.commissionScopeLabel}'
            : 'Gaji bulanan Rp ${employee.monthlySalary?.toStringAsFixed(0)}',
      ),
      trailing: Chip(label: Text(employee.isActive ? 'Aktif' : 'Nonaktif')),
    ),
  );
}
