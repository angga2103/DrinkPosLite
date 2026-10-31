import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state_view.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final SettingsRepository _repo = SettingsRepository();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _repo.getBackupHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isProcessing = true);
    final user = ref.read(authProvider).currentUser;

    final result = await BackupService.createBackup(
      backupType: 'MANUAL',
      userId: user?.id,
    );

    setState(() => _isProcessing = false);

    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup berhasil dibuat: ${result.fileName}'),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'Bagikan',
            textColor: Colors.white,
            onPressed: () {
              if (result.filePath != null && result.fileName != null) {
                BackupService.shareBackupFile(result.filePath!, result.fileName!);
              }
            },
          ),
        ),
      );
      _loadHistory();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Gagal membuat backup'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null || !user.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya Pemilik (Owner) yang dapat memulihkan database')),
      );
      return;
    }

    // Pick file
    final pickedFile = await FilePicker.pickFile(
      type: FileType.any,
    );

    if (pickedFile == null) return;
    final filePath = pickedFile.path;
    if (filePath == null) return;

    // Show confirmation dialog with critical warning
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Peringatan Pemulihan Database',
      message: 'PERINGATAN PENTING:\n\n'
          'Memulihkan database akan menggantikan seluruh data transaksi, produk, dan stok dengan data dari file backup yang dipilih.\n\n'
          'Sistem akan otomatis membuat cadangan keamanan dari database saat ini sebelum proses pemulihan.\n\n'
          'Apakah Anda yakin ingin melanjutkan?',
      confirmText: 'Ya, Pulihkan Sekarang',
      confirmColor: AppColors.danger,
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);

      final result = await BackupService.restoreFromBackup(
        backupFilePath: filePath,
        ownerUserId: user.id,
      );

      setState(() => _isProcessing = false);

      if (result.success && mounted) {
        ref.read(dashboardProvider.notifier).loadMetrics();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore Berhasil!'),
            content: Text('Database berhasil dipulihkan dari ${result.fileName}.\nIntegritas data terverifikasi aman.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _loadHistory();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Pemulihan Gagal', style: TextStyle(color: AppColors.danger)),
            content: Text(result.errorMessage ?? 'Gagal memulihkan database'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Backup & Restore Database',
      currentRoute: '/backup',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Banner
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
                          const Row(
                            children: [
                              Icon(Icons.security, color: AppColors.primary, size: 22),
                              SizedBox(width: 8),
                              Text('Keamanan Data Offline-First', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Semua data toko tersimpan di perangkat lokal. Buat cadangan secara rutin dan simpan file backup ke Google Drive, kartu SD, atau kirim ke WhatsApp agar data selalu aman.',
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: _isProcessing
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.backup),
                                  label: const Text('Backup Sekarang'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                  onPressed: _isProcessing ? null : _createBackup,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.restore),
                                  label: const Text('Restore Data'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.primary),
                                  ),
                                  onPressed: _isProcessing ? null : _restoreBackup,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text('Riwayat Backup Tersimpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  if (_history.isEmpty)
                    const EmptyStateView(
                      icon: Icons.backup_table_outlined,
                      title: 'Belum Ada Backup',
                      message: 'Tekan tombol "Backup Sekarang" untuk membuat cadangan database pertama Anda.',
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final b = _history[index];
                        final sizeKb = ((b['file_size_bytes'] as int? ?? 0) / 1024).toStringAsFixed(1);
                        final path = b['file_path'] as String? ?? '';
                        final name = b['file_name'] as String? ?? '';

                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primaryContainer,
                              child: Icon(Icons.storage, color: AppColors.primary, size: 20),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('Ukuran: $sizeKb KB • Tgl: ${DateFormatter.formatDateTime(DateTime.tryParse(b['backup_date'] ?? ''))}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.share_outlined, color: AppColors.primary),
                              tooltip: 'Bagikan File Backup',
                              onPressed: () {
                                if (path.isNotEmpty) {
                                  BackupService.shareBackupFile(path, name);
                                }
                              },
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
