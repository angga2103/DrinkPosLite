import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/audit_model.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../widgets/empty_state_view.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final SettingsRepository _repo = SettingsRepository();
  List<AuditLogModel> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await _repo.getAuditLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  String _formatActionName(String action) {
    switch (action.toUpperCase()) {
      case 'TRANSACTION_CANCEL':
      case 'CANCEL_TRANSACTION':
        return 'Pembatalan Transaksi / Nota';
      case 'UPDATE_PRODUCT_PRICE':
        return 'Perubahan Harga Menu';
      case 'DELETE_PRODUCT':
        return 'Penghapusan Menu Produk';
      case 'STOCK_ADJUSTMENT':
        return 'Penyesuaian Stok Manual';
      case 'STOCK_OPNAME':
        return 'Stok Opname Bahan Baku';
      case 'UPDATE_PURCHASE_PRICE':
        return 'Pembaruan Harga Beli Bahan';
      case 'CREATE_PURCHASE':
        return 'Catatan Pembelian Bahan';
      case 'SYNC_PACKAGE_APPLIED':
        return 'Pembaruan Resep & Stok via WhatsApp';
      case 'STORE_PROFILE_UPDATE':
      case 'STORE_UPDATE':
        return 'Pembaruan Profil & Logo Toko';
      case 'CHANGE_PIN':
        return 'Perubahan PIN Pegawai';
      case 'USER_LOCKED':
        return 'Akun Terkunci (Salah PIN Berulang)';
      case 'UNLOCK_USER':
        return 'Buka Kunci Akun Pegawai';
      case 'DELETE_EMPLOYEE':
        return 'Penghapusan Profil Pegawai';
      case 'SAVE_EMPLOYEE':
        return 'Pembaruan Data & Hak Akses Pegawai';
      case 'CREATE_BACKUP':
        return 'Pencadangan Database (Backup)';
      case 'RESTORE_BACKUP':
        return 'Pemulihan Database (Restore)';
      case 'OPEN_SHIFT':
        return 'Buka Kasir / Mulai Shift';
      case 'CLOSE_SHIFT':
        return 'Tutup Kasir & Setor Uang Kas';
      case 'CANCEL_EXPENSE':
        return 'Pembatalan Catatan Pengeluaran';
      default:
        // Format generic SCREAMING_SNAKE_CASE to readable text
        return action.replaceAll('_', ' ').toLowerCase().split(' ').map((w) {
          if (w.isEmpty) return '';
          return w[0].toUpperCase() + w.substring(1);
        }).join(' ');
    }
  }

  IconData _getIconForAction(String action) {
    final act = action.toUpperCase();
    if (act.contains('CANCEL') || act.contains('DELETE')) return Icons.cancel_outlined;
    if (act.contains('LOCK')) return Icons.lock_outline;
    if (act.contains('PIN')) return Icons.password_outlined;
    if (act.contains('PRICE') || act.contains('PURCHASE')) return Icons.monetization_on_outlined;
    if (act.contains('STOCK') || act.contains('OPNAME')) return Icons.inventory_2_outlined;
    if (act.contains('SYNC')) return Icons.sync_alt_outlined;
    if (act.contains('STORE')) return Icons.storefront_outlined;
    if (act.contains('SHIFT')) return Icons.work_history_outlined;
    if (act.contains('BACKUP') || act.contains('RESTORE')) return Icons.storage_outlined;
    return Icons.history_outlined;
  }

  Color _getColorForAction(String action) {
    final act = action.toUpperCase();
    if (act.contains('CANCEL') || act.contains('DELETE') || act.contains('LOCKED')) {
      return AppColors.danger;
    }
    if (act.contains('SYNC') || act.contains('RESTORE') || act.contains('OPNAME')) {
      return AppColors.secondary;
    }
    if (act.contains('PRICE') || act.contains('STORE') || act.contains('UNLOCK')) {
      return AppColors.primary;
    }
    return AppColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Aktivitas & Keamanan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const EmptyStateView(
                  icon: Icons.history_toggle_off,
                  title: 'Belum Ada Riwayat Aktivitas',
                  message: 'Aktivitas perubahan harga, resep, pembatalan transaksi, dan pergantian data penting akan otomatis dicatat di sini.',
                )
              : RefreshIndicator(
                  onRefresh: _loadLogs,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final color = _getColorForAction(log.action);
                      final actionLabel = _formatActionName(log.action);

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: color.withOpacity(0.12),
                                child: Icon(_getIconForAction(log.action), color: color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            actionLabel,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: color == AppColors.danger ? AppColors.danger : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          DateFormatter.formatDateTime(DateTime.tryParse(log.createdAt)),
                                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Oleh: ${log.userName ?? "Sistem"}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                    ),
                                    if (log.reason != null && log.reason!.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Text(
                                          'Keterangan: ${log.reason}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                    if (log.oldValue != null && log.newValue != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Perubahan: "${log.oldValue}" → "${log.newValue}"',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
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
