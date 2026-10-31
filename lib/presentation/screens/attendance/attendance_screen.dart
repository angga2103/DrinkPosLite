import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state_view.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final AttendanceRepository _attRepo = AttendanceRepository();
  final EmployeeRepository _empRepo = EmployeeRepository();

  List<AttendanceModel> _history = [];
  List<UserModel> _employees = [];
  AttendanceModel? _todayAttendance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = ref.read(authProvider).currentUser;
    final emps = await _empRepo.getEmployees(activeOnly: true);
    final history = await _attRepo.getAttendanceHistory();

    AttendanceModel? todayAtt;
    if (user != null) {
      todayAtt = await _attRepo.getTodayAttendance(user.id);
    }

    if (mounted) {
      setState(() {
        _employees = emps;
        _history = history;
        _todayAttendance = todayAtt;
        _isLoading = false;
      });
    }
  }

  void _showClockInOutDialog(bool isClockIn) {
    String? selectedUserId = ref.read(authProvider).currentUser?.id;
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(isClockIn ? 'Clock-In (Masuk Shift)' : 'Clock-Out (Pulang Shift)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih Pegawai:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedUserId,
                items: _employees.map((e) {
                  return DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.role})'));
                }).toList(),
                onChanged: (val) => setModalState(() => selectedUserId = val),
              ),
              if (selectedUserId != null) ...[
                Builder(
                  builder: (_) {
                    final emp = _employees.firstWhere((e) => e.id == selectedUserId, orElse: () => _employees.first);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Jadwal: ${emp.shiftName} (${emp.shiftStartTime} - ${emp.shiftEndTime})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 14),
              const Text('Masukkan PIN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(hintText: 'PIN Pegawai', prefixIcon: Icon(Icons.lock_outline)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (selectedUserId == null || pinController.text.isEmpty) return;

                try {
                  if (isClockIn) {
                    final emp = _employees.firstWhere((e) => e.id == selectedUserId, orElse: () => _employees.first);
                    await _attRepo.clockIn(
                      userId: selectedUserId!,
                      enteredPin: pinController.text.trim(),
                      scheduledIn: emp.shiftStartTime,
                    );
                  } else {
                    await _attRepo.clockOut(
                      userId: selectedUserId!,
                      enteredPin: pinController.text.trim(),
                    );
                  }

                  if (mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isClockIn ? 'Clock-in berhasil!' : 'Clock-out berhasil!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    _loadData();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
                  );
                }
              },
              child: Text(isClockIn ? 'Clock-In' : 'Clock-Out'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;

    return AppScaffold(
      title: 'Absensi Pegawai',
      currentRoute: '/attendance',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clock in/out action card
                  Card(
                    color: AppColors.primaryContainer.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.primaryLight),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Absensi Hari Ini (${DateFormatter.formatDate(DateTime.now())})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                user?.name ?? 'Pegawai',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Jam Masuk', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _todayAttendance?.clockIn ?? '--:--',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  if (_todayAttendance != null && _todayAttendance!.latenessMinutes > 0)
                                    Text(
                                      'Terlambat ${_todayAttendance!.latenessMinutes} mnt',
                                      style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                              Container(width: 1, height: 40, color: AppColors.cardBorder),
                              Column(
                                children: [
                                  const Text('Jam Pulang', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _todayAttendance?.clockOut ?? '--:--',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.login),
                                  label: const Text('Clock-In'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                  onPressed: () => _showClockInOutDialog(true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Clock-Out'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(color: AppColors.danger),
                                  ),
                                  onPressed: () => _showClockInOutDialog(false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text('Riwayat Absensi Terakhir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  if (_history.isEmpty)
                    const EmptyStateView(
                      icon: Icons.access_time,
                      title: 'Belum Ada Riwayat Absensi',
                      message: 'Lakukan clock-in menggunakan PIN untuk mencatat kehadiran.',
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final a = _history[index];
                        final isLate = a.latenessMinutes > 0;

                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isLate ? AppColors.warningContainer : AppColors.successContainer,
                              child: Icon(
                                isLate ? Icons.timer_outlined : Icons.check,
                                color: isLate ? AppColors.secondary : AppColors.success,
                                size: 20,
                              ),
                            ),
                            title: Text(a.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('Tgl: ${a.date} • Masuk: ${a.clockIn ?? "-"} • Pulang: ${a.clockOut ?? "-"}'),
                            trailing: isLate
                                ? Text(
                                    'Telat ${a.latenessMinutes}m',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger),
                                  )
                                : const Text(
                                    'Tepat Waktu',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                                  ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
