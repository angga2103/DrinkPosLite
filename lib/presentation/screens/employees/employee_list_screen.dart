import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state_view.dart';
import 'employee_form_screen.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  final EmployeeRepository _empRepo = EmployeeRepository();
  List<UserModel> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final emps = await _empRepo.getEmployees();
    if (mounted) {
      setState(() {
        _employees = emps;
        _isLoading = false;
      });
    }
  }

  Future<void> _unlockAccount(UserModel emp) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Buka Kunci Akun',
      message: 'Apakah Anda ingin membuka kunci akun "${emp.name}"? Pengguna akan dapat mencoba login kembali.',
      confirmText: 'Buka Kunci',
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).unlockUser(emp.id);
      _loadData();
    }
  }

  Future<void> _deleteEmployee(UserModel emp) async {
    final currentUser = ref.read(authProvider).currentUser;
    if (currentUser == null || !currentUser.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya Pemilik (Owner) yang dapat menghapus pegawai!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (emp.id == currentUser.id || emp.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil Pemilik (Owner) tidak dapat dihapus!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Hapus Pegawai',
      message: 'Apakah Anda yakin ingin menghapus data pegawai "${emp.name}" secara permanen?\n\nRiwayat aktivitas pegawai ini tetap tercatat di sistem audit log.',
      confirmText: 'Ya, Hapus Permanen',
      confirmColor: AppColors.danger,
    );

    if (confirmed == true) {
      final success = await _empRepo.deleteEmployee(emp.id, currentUser.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pegawai "${emp.name}" berhasil dihapus'), backgroundColor: AppColors.success),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menghapus pegawai!'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).currentUser;
    final isOwner = currentUser?.isOwner ?? false;

    return AppScaffold(
      title: 'Kelola Pegawai',
      currentRoute: '/employees',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Tambah Pegawai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
          );
          if (res == true) _loadData();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? const EmptyStateView(
                  icon: Icons.people_outline,
                  title: 'Belum Ada Pegawai',
                  message: 'Tekan tombol Tambah Pegawai untuk mendaftarkan staf baru.',
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _employees.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final emp = _employees[index];
                      final isEmpOwner = emp.isOwner;

                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: isEmpOwner
                                    ? AppColors.primaryContainer
                                    : (emp.isManager ? AppColors.secondaryContainer : AppColors.background),
                                child: Text(
                                  emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isEmpOwner ? AppColors.primary : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            emp.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ),
                                        if (emp.isLocked) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.dangerContainer,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'TERKUNCI',
                                              style: TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isEmpOwner ? Colors.purple.shade50 : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: isEmpOwner ? Colors.purple.shade200 : Colors.blue.shade200),
                                          ),
                                          child: Text(
                                            emp.role.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isEmpOwner ? Colors.purple.shade800 : Colors.blue.shade800,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isEmpOwner ? 'Akses Penuh' : '${emp.permissions.length} Menu Diizinkan',
                                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${emp.shiftName}: ${emp.shiftStartTime} - ${emp.shiftEndTime}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (emp.isLocked)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, padding: const EdgeInsets.symmetric(horizontal: 10)),
                                  onPressed: () => _unlockAccount(emp),
                                  child: const Text('Buka Kunci', style: TextStyle(fontSize: 11)),
                                )
                              else
                                PopupMenuButton<String>(
                                  onSelected: (val) async {
                                    if (val == 'edit') {
                                      final res = await Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => EmployeeFormScreen(employee: emp)),
                                      );
                                      if (res == true) _loadData();
                                    } else if (val == 'delete') {
                                      _deleteEmployee(emp);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18, color: AppColors.textPrimary),
                                          SizedBox(width: 8),
                                          Text('Edit Data & Hak Akses'),
                                        ],
                                      ),
                                    ),
                                    if (isOwner && !isEmpOwner && emp.id != currentUser?.id)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_forever, size: 18, color: AppColors.danger),
                                            SizedBox(width: 8),
                                            Text('Hapus Pegawai', style: TextStyle(color: AppColors.danger)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
