import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../providers/auth_provider.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  final UserModel? employee;

  const EmployeeFormScreen({super.key, this.employee});

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final EmployeeRepository _repo = EmployeeRepository();

  late TextEditingController _nameController;
  late TextEditingController _pinController;
  late TextEditingController _shiftNameController;
  late TextEditingController _shiftStartTimeController;
  late TextEditingController _shiftEndTimeController;
  String _role = AppConstants.roleCashier;
  bool _isActive = true;
  bool _isSaving = false;

  late Set<String> _selectedPermissions;

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _nameController = TextEditingController(text: emp?.name ?? '');
    _pinController = TextEditingController();
    _shiftNameController = TextEditingController(text: emp?.shiftName ?? 'Shift Pagi');
    _shiftStartTimeController = TextEditingController(text: emp?.shiftStartTime ?? '08:00');
    _shiftEndTimeController = TextEditingController(text: emp?.shiftEndTime ?? '16:00');
    _role = emp?.role ?? AppConstants.roleCashier;
    _isActive = emp?.isActive ?? true;

    if (emp != null) {
      if (emp.permissions.isNotEmpty) {
        _selectedPermissions = emp.permissions.toSet();
      } else if (emp.isManager) {
        _selectedPermissions = {'pos', 'products', 'inventory', 'purchases', 'expenses', 'shifts', 'attendance', 'reports'};
      } else {
        _selectedPermissions = {'pos', 'attendance'};
      }
    } else {
      _selectedPermissions = {'pos', 'attendance'};
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final currentParts = controller.text.split(':');
    final initialHour = currentParts.length == 2 ? int.tryParse(currentParts[0]) ?? 8 : 8;
    final initialMinute = currentParts.length == 2 ? int.tryParse(currentParts[1]) ?? 0 : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      setState(() {
        controller.text = '$hourStr:$minuteStr';
      });
    }
  }

  void _onRoleChanged(String newRole) {
    setState(() {
      _role = newRole;
      if (newRole == AppConstants.roleOwner) {
        _selectedPermissions = UserModel.availableMenuLabels.keys.toSet();
      } else if (newRole == AppConstants.roleManager) {
        _selectedPermissions = {'pos', 'products', 'inventory', 'purchases', 'expenses', 'shifts', 'attendance', 'reports'};
      } else {
        _selectedPermissions = {'pos', 'attendance'};
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.employee == null && (_pinController.text.length < 4 || _pinController.text.length > 6)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN harus terdiri dari 4-6 digit angka')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final operator = ref.read(authProvider).currentUser;
    final id = widget.employee?.id ?? IdGenerator.generateId(prefix: 'usr');
    final isCurrentOperatorOwner = operator?.isOwner ?? false;

    final emp = UserModel(
      id: id,
      name: _nameController.text.trim(),
      role: _role,
      pinHash: widget.employee?.pinHash ?? '',
      isActive: _isActive,
      isLocked: widget.employee?.isLocked ?? false,
      failedAttempts: widget.employee?.failedAttempts ?? 0,
      joinDate: widget.employee?.joinDate ?? DateTime.now().toIso8601String().substring(0, 10),
      shiftName: isCurrentOperatorOwner
          ? (_shiftNameController.text.trim().isNotEmpty ? _shiftNameController.text.trim() : 'Shift Pagi')
          : (widget.employee?.shiftName ?? 'Shift Pagi'),
      shiftStartTime: isCurrentOperatorOwner
          ? (_shiftStartTimeController.text.trim().isNotEmpty ? _shiftStartTimeController.text.trim() : '08:00')
          : (widget.employee?.shiftStartTime ?? '08:00'),
      shiftEndTime: isCurrentOperatorOwner
          ? (_shiftEndTimeController.text.trim().isNotEmpty ? _shiftEndTimeController.text.trim() : '16:00')
          : (widget.employee?.shiftEndTime ?? '16:00'),
      permissions: isCurrentOperatorOwner
          ? _selectedPermissions.toList()
          : (widget.employee?.permissions ?? _selectedPermissions.toList()),
    );

    await _repo.saveEmployee(
      employee: emp,
      newRawPin: _pinController.text.isNotEmpty ? _pinController.text.trim() : null,
      operatorUserId: operator?.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data pegawai & hak akses berhasil disimpan!'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.employee != null;
    final isCurrentOwner = ref.watch(authProvider).currentUser?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Pegawai & Hak Akses' : 'Tambah Pegawai Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              const Text('Nama Lengkap Pegawai', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Contoh: Ahmad Kasir'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // Role
              const Text('Jabatan / Peran Utama', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Kasir'),
                    selected: _role == AppConstants.roleCashier,
                    selectedColor: AppColors.primaryContainer,
                    onSelected: isCurrentOwner ? (_) => _onRoleChanged(AppConstants.roleCashier) : null,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Manager'),
                    selected: _role == AppConstants.roleManager,
                    selectedColor: AppColors.primaryContainer,
                    onSelected: isCurrentOwner ? (_) => _onRoleChanged(AppConstants.roleManager) : null,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Pemilik (Owner)'),
                    selected: _role == AppConstants.roleOwner,
                    selectedColor: AppColors.primaryContainer,
                    onSelected: isCurrentOwner ? (_) => _onRoleChanged(AppConstants.roleOwner) : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // PIN
              Text(
                isEditing ? 'PIN Baru (Kosongkan jika tidak ingin mengubah)' : 'PIN Keamanan (4-6 digit angka)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  hintText: 'Masukkan 4-6 angka rahasia',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (val) {
                  if (!isEditing && (val == null || val.length < 4)) {
                    return 'PIN minimal 4 angka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Shift Schedule (Owner Only can edit)
              Card(
                color: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text('Jadwal Waktu Shift Kerja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const Spacer(),
                          if (!isCurrentOwner)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.warningContainer, borderRadius: BorderRadius.circular(4)),
                              child: const Text('HANYA OWNER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.warning)),
                            ),
                        ],
                      ),
                      if (!isCurrentOwner) ...[
                        const SizedBox(height: 4),
                        const Text('Hanya Pemilik (Owner) yang berhak mengubah jadwal shift ini.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _shiftNameController,
                        enabled: isCurrentOwner,
                        decoration: const InputDecoration(labelText: 'Nama Shift (contoh: Shift Pagi, Shift Sore)'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _shiftStartTimeController,
                              readOnly: true,
                              enabled: isCurrentOwner,
                              onTap: isCurrentOwner ? () => _pickTime(_shiftStartTimeController) : null,
                              decoration: const InputDecoration(
                                labelText: 'Jam Masuk',
                                suffixIcon: Icon(Icons.schedule, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _shiftEndTimeController,
                              readOnly: true,
                              enabled: isCurrentOwner,
                              onTap: isCurrentOwner ? () => _pickTime(_shiftEndTimeController) : null,
                              decoration: const InputDecoration(
                                labelText: 'Jam Pulang',
                                suffixIcon: Icon(Icons.schedule, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Checklist Hak Akses Menu (Item 11: Owner checklist)
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Hak Akses Menu & Fitur',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                            ),
                          ),
                          if (isCurrentOwner) ...[
                            TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                              onPressed: () {
                                setState(() {
                                  _selectedPermissions = UserModel.availableMenuLabels.keys.toSet();
                                });
                              },
                              child: const Text('Pilih Semua', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Centang menu yang boleh diakses oleh pegawai ini. Menu yang tidak dicentang akan disembunyikan.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const Divider(height: 16),
                      ...UserModel.availableMenuLabels.entries.map((entry) {
                        final key = entry.key;
                        final label = entry.value;
                        final isChecked = _selectedPermissions.contains(key);

                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          value: isChecked,
                          activeColor: AppColors.primary,
                          onChanged: isCurrentOwner
                              ? (bool? val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedPermissions.add(key);
                                    } else {
                                      _selectedPermissions.remove(key);
                                    }
                                  });
                                }
                              : null,
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Active status
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Status Pegawai Aktif', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Pegawai non-aktif tidak dapat masuk ke sistem POS'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(isEditing ? 'Perbarui Pegawai & Hak Akses' : 'Simpan Pegawai'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
