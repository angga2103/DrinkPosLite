import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/attendance_photo_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
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

  /// Dialog Clock-In atau Clock-Out dengan Selfie Kamera Depan & Watermark
  void _showClockInOutDialog(bool isClockIn) {
    String? selectedUserId = ref.read(authProvider).currentUser?.id;
    if (selectedUserId == null && _employees.isNotEmpty) {
      selectedUserId = _employees.first.id;
    }
    final pinController = TextEditingController();
    File? capturedSelfie;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentEmp = _employees.firstWhere(
            (e) => e.id == selectedUserId,
            orElse: () => _employees.isNotEmpty ? _employees.first : UserModel(
              id: 'unknown',
              name: 'Pegawai',
              role: 'cashier',
              pinHash: '',
              shiftName: 'Shift Reguler',
              shiftStartTime: '08:00',
              shiftEndTime: '16:00',
            ),
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isClockIn ? AppColors.primaryContainer : AppColors.dangerContainer,
                  radius: 18,
                  child: Icon(
                    isClockIn ? Icons.login : Icons.logout,
                    color: isClockIn ? AppColors.primary : AppColors.danger,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isClockIn ? 'Clock-In (Masuk Shift)' : 'Clock-Out (Pulang Shift)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pilih Pegawai:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedUserId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _employees.map((e) {
                      return DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.role})'));
                    }).toList(),
                    onChanged: isProcessing
                        ? null
                        : (val) {
                            setModalState(() {
                              selectedUserId = val;
                              capturedSelfie = null; // reset jika ganti user
                            });
                          },
                  ),
                  const SizedBox(height: 8),

                  // Jadwal Shift Info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Jadwal: ${currentEmp.shiftName} (${currentEmp.shiftStartTime} - ${currentEmp.shiftEndTime})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Masukkan PIN:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: pinController,
                    enabled: !isProcessing,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: 'PIN Pegawai',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Foto Selfie Anti-Manipulasi
                  Row(
                    children: [
                      const Text(
                        'Foto Selfie di Kedai:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Anti-Kecurangan', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (capturedSelfie == null) ...[
                    InkWell(
                      onTap: isProcessing
                          ? null
                          : () async {
                              final photo = await AttendancePhotoService.captureSelfie();
                              if (photo != null) {
                                setModalState(() => capturedSelfie = photo);
                              }
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: const Icon(Icons.camera_front, color: AppColors.primary, size: 26),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ambil Foto Selfie Depan',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Foto akan dibubuhi watermark tanggal, jam & toko secara permanen',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Image.file(
                            capturedSelfie!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            width: double.infinity,
                            color: Colors.black.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.success, size: 14),
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Text(
                                    'Selfie berhasil diambil',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                InkWell(
                                  onTap: isProcessing
                                      ? null
                                      : () async {
                                          final photo = await AttendancePhotoService.captureSelfie();
                                          if (photo != null) {
                                            setModalState(() => capturedSelfie = photo);
                                          }
                                        },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      'Ulangi',
                                      style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (isProcessing) ...[
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Membubuhkan watermark permanen...',
                          style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClockIn ? AppColors.primary : AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        if (selectedUserId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pilih pegawai terlebih dahulu')),
                          );
                          return;
                        }
                        if (pinController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Masukkan PIN pegawai')),
                          );
                          return;
                        }

                        setModalState(() => isProcessing = true);

                        try {
                          File? watermarkedFile;
                          final storeName = ref.read(settingsProvider).store.name;
                          final now = DateTime.now();
                          final clockTimeStr =
                              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                          // Perhitungan estimasi lateness untuk watermark
                          int estLateness = 0;
                          if (isClockIn) {
                            try {
                              final parts = currentEmp.shiftStartTime.split(':');
                              final sH = int.parse(parts[0]);
                              final sM = int.parse(parts[1]);
                              final sched = DateTime(now.year, now.month, now.day, sH, sM);
                              if (now.isAfter(sched)) {
                                estLateness = now.difference(sched).inMinutes;
                              }
                            } catch (_) {}
                          }

                          // 1. Watermark foto jika ada selfie
                          if (capturedSelfie != null) {
                            watermarkedFile = await AttendancePhotoService.applyWatermark(
                              originalFile: capturedSelfie!,
                              storeName: storeName,
                              employeeName: currentEmp.name,
                              actionType: isClockIn ? 'CLOCK-IN' : 'CLOCK-OUT',
                              status: isClockIn
                                  ? (estLateness > 0 ? 'TERLAMBAT' : 'HADIR')
                                  : 'PULANG',
                              latenessMinutes: estLateness,
                              shiftSchedule: '${currentEmp.shiftStartTime} - ${currentEmp.shiftEndTime}',
                            );
                          }

                          // 2. Simpan absensi ke database
                          AttendanceModel resultAtt;
                          if (isClockIn) {
                            resultAtt = await _attRepo.clockIn(
                              userId: selectedUserId!,
                              enteredPin: pinController.text.trim(),
                              scheduledIn: currentEmp.shiftStartTime,
                              photoPath: watermarkedFile?.path,
                            );
                          } else {
                            resultAtt = await _attRepo.clockOut(
                              userId: selectedUserId!,
                              enteredPin: pinController.text.trim(),
                              scheduledOut: currentEmp.shiftEndTime,
                              photoPath: watermarkedFile?.path,
                            );
                          }

                          if (mounted) {
                            Navigator.of(ctx).pop(); // Tutup dialog clock in
                            await _loadData();

                            // 3. Tampilkan modal sukses + Kirim Bukti WhatsApp
                            _showAttendanceSuccessDialog(
                              isClockIn: isClockIn,
                              employeeName: currentEmp.name,
                              storeName: storeName,
                              attendance: resultAtt,
                              watermarkedFile: watermarkedFile,
                              shiftSchedule: '${currentEmp.shiftStartTime} - ${currentEmp.shiftEndTime}',
                              clockTime: clockTimeStr,
                            );
                          }
                        } catch (e) {
                          setModalState(() => isProcessing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
                          );
                        }
                      },
                child: Text(isClockIn ? 'Clock-In' : 'Clock-Out'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog Sukses & Opsi Kirim Bukti ke WhatsApp
  void _showAttendanceSuccessDialog({
    required bool isClockIn,
    required String employeeName,
    required String storeName,
    required AttendanceModel attendance,
    required File? watermarkedFile,
    required String shiftSchedule,
    required String clockTime,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.successContainer,
              child: Icon(Icons.check_circle_outline, color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              isClockIn ? 'Clock-In Berhasil!' : 'Clock-Out Berhasil!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Pegawai', employeeName),
                    const Divider(height: 12),
                    _buildInfoRow('Waktu', '$clockTime WIB'),
                    const Divider(height: 12),
                    _buildInfoRow('Jadwal', shiftSchedule),
                    const Divider(height: 12),
                    _buildInfoRow(
                      'Status',
                      attendance.latenessMinutes > 0
                          ? 'Terlambat ${attendance.latenessMinutes} Menit'
                          : attendance.status,
                      valueColor: attendance.latenessMinutes > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ],
                ),
              ),

              if (watermarkedFile != null && watermarkedFile.existsSync()) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(watermarkedFile, height: 130, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Foto telah dibubuhi watermark permanen',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (watermarkedFile != null && watermarkedFile.existsSync()) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share, color: Colors.white, size: 18),
                label: const Text(
                  'Kirim Bukti ke WhatsApp Owner',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await AttendancePhotoService.shareAttendanceToWhatsApp(
                    photoFile: watermarkedFile,
                    storeName: storeName,
                    employeeName: employeeName,
                    actionType: isClockIn ? 'CLOCK-IN' : 'CLOCK-OUT',
                    status: attendance.status,
                    latenessMinutes: attendance.latenessMinutes,
                    clockTime: clockTime,
                    shiftSchedule: shiftSchedule,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog Catat Izin / Sakit / Alpa oleh Owner / Manager
  void _showRecordLeaveDialog() {
    String? selectedUserId = _employees.isNotEmpty ? _employees.first.id : null;
    String selectedStatus = 'IZIN';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.event_note, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Catat Izin / Sakit Pegawai', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Pegawai:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedUserId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _employees.map((e) {
                    return DropdownMenuItem(value: e.id, child: Text('${e.name} (${e.role})'));
                  }).toList(),
                  onChanged: (val) => setModalState(() => selectedUserId = val),
                ),
                const SizedBox(height: 14),

                const Text('Jenis Ketidakhadiran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'IZIN', child: Text('Izin')),
                    DropdownMenuItem(value: 'SAKIT', child: Text('Sakit')),
                    DropdownMenuItem(value: 'ALPA', child: Text('Alpa (Tanpa Keterangan)')),
                  ],
                  onChanged: (val) => setModalState(() => selectedStatus = val ?? 'IZIN'),
                ),
                const SizedBox(height: 14),

                const Text('Alasan / Keterangan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Izin urusan keluarga, flu berat, dll.',
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedUserId == null) return;
                try {
                  final operatorUser = ref.read(authProvider).currentUser;
                  await _attRepo.recordLeave(
                    userId: selectedUserId!,
                    status: selectedStatus,
                    notes: notesController.text.trim(),
                    recordedByUserId: operatorUser?.id ?? 'system',
                  );
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ketidakhadiran ($selectedStatus) berhasil dicatat.'), backgroundColor: AppColors.success),
                    );
                    _loadData();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog Lihat Detail Riwayat Absensi + Foto Bukti
  void _showAttendanceDetail(AttendanceModel a) {
    final hasPhoto = a.photoPath != null && File(a.photoPath!).existsSync();
    final file = hasPhoto ? File(a.photoPath!) : null;
    final storeName = ref.read(settingsProvider).store.name;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer,
              child: Icon(Icons.badge_outlined, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detail Absensi - ${a.userName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Tanggal', a.date),
                    const Divider(height: 12),
                    _buildInfoRow('Jam Masuk', a.clockIn ?? '--:--'),
                    const Divider(height: 12),
                    _buildInfoRow('Jam Pulang', a.clockOut ?? '--:--'),
                    const Divider(height: 12),
                    _buildInfoRow(
                      'Status',
                      a.latenessMinutes > 0 ? 'Terlambat ${a.latenessMinutes} Menit' : a.status,
                      valueColor: a.latenessMinutes > 0 ? AppColors.danger : AppColors.success,
                    ),
                    if (a.notes != null && a.notes!.isNotEmpty) ...[
                      const Divider(height: 12),
                      _buildInfoRow('Keterangan', a.notes!),
                    ],
                  ],
                ),
              ),

              if (hasPhoto && file != null) ...[
                const SizedBox(height: 12),
                const Text('Foto Selfie Ter-Watermark:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(file, height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (hasPhoto && file != null) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Kirim ke WhatsApp'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
              onPressed: () async {
                await AttendancePhotoService.shareAttendanceToWhatsApp(
                  photoFile: file,
                  storeName: storeName,
                  employeeName: a.userName,
                  actionType: a.clockOut != null ? 'CLOCK-OUT' : 'CLOCK-IN',
                  status: a.status,
                  latenessMinutes: a.latenessMinutes,
                  clockTime: a.clockOut ?? (a.clockIn ?? '--:--'),
                  shiftSchedule: a.scheduledIn,
                );
              },
            ),
          ],
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor ?? AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    final isOwnerOrManager = user?.isOwner == true || user?.isManager == true;

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
                    elevation: 1,
                    color: AppColors.primaryContainer.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormatter.formatDate(DateTime.now()),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text('Absensi Hari Ini', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  user?.name ?? 'Pegawai',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
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
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.dangerContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Terlambat ${_todayAttendance!.latenessMinutes}m',
                                        style: const TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              Container(width: 1, height: 42, color: AppColors.cardBorder),
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
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  label: const Text('Clock-In'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _showClockInOutDialog(true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.logout, size: 18),
                                  label: const Text('Clock-Out'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(color: AppColors.danger),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _showClockInOutDialog(false),
                                ),
                              ),
                            ],
                          ),

                          if (isOwnerOrManager) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                icon: const Icon(Icons.event_note, size: 16),
                                label: const Text('Catat Izin / Sakit Pegawai (Khusus Owner/Manager)'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: _showRecordLeaveDialog,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Riwayat Absensi Terakhir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Muat Ulang',
                        onPressed: _loadData,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_history.isEmpty)
                    const EmptyStateView(
                      icon: Icons.access_time,
                      title: 'Belum Ada Riwayat Absensi',
                      message: 'Lakukan clock-in menggunakan selfie kamera depan untuk mencatat kehadiran.',
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
                        final hasPhoto = a.photoPath != null && File(a.photoPath!).existsSync();
                        final isLeave = a.status == 'IZIN' || a.status == 'SAKIT' || a.status == 'ALPA';

                        Color badgeBg = AppColors.successContainer;
                        Color badgeColor = AppColors.success;
                        IconData badgeIcon = Icons.check;

                        if (isLeave) {
                          badgeBg = Colors.blue.shade50;
                          badgeColor = Colors.blue.shade700;
                          badgeIcon = Icons.medical_services_outlined;
                        } else if (isLate) {
                          badgeBg = AppColors.warningContainer;
                          badgeColor = AppColors.secondary;
                          badgeIcon = Icons.timer_outlined;
                        }

                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            onTap: () => _showAttendanceDetail(a),
                            leading: CircleAvatar(
                              backgroundColor: badgeBg,
                              child: Icon(badgeIcon, color: badgeColor, size: 20),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    a.userName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                if (hasPhoto) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.photo_camera, size: 12, color: AppColors.primary),
                                        SizedBox(width: 4),
                                        Text('Foto', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text('Tgl: ${a.date} • Masuk: ${a.clockIn ?? "-"} • Pulang: ${a.clockOut ?? "-"}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (isLeave)
                                  Text(
                                    a.status,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor),
                                  )
                                else if (isLate)
                                  Text(
                                    'Telat ${a.latenessMinutes}m',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger),
                                  )
                                else
                                  const Text(
                                    'Tepat Waktu',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                                  ),
                                const SizedBox(height: 2),
                                const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                              ],
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
