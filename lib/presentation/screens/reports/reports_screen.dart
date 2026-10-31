import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/share_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/report_model.dart';
import '../../../data/repositories/pos_repository.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/app_scaffold.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final ReportRepository _reportRepo = ReportRepository();
  final PosRepository _posRepo = PosRepository();

  String _selectedPeriod = 'TODAY'; // TODAY, WEEK, MONTH, CUSTOM
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  SalesReportData? _reportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setPeriod('TODAY');
  }

  void _setPeriod(String period) {
    _selectedPeriod = period;
    final now = DateTime.now();

    if (period == 'TODAY') {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day);
    } else if (period == 'WEEK') {
      _startDate = now.subtract(Duration(days: now.weekday - 1));
      _endDate = now;
    } else if (period == 'MONTH') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
    }
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final data = await _reportRepo.getSalesReport(
      startDate: _startDate,
      endDate: _endDate,
      periodTitle: _selectedPeriod == 'TODAY'
          ? 'Laporan Hari Ini'
          : (_selectedPeriod == 'WEEK'
              ? 'Laporan Minggu Ini'
              : (_selectedPeriod == 'MONTH' ? 'Laporan Bulan Ini' : 'Laporan Rentang Kustom')),
    );
    if (mounted) {
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    }
  }

  void _showShareOptions() {
    if (_reportData == null) return;
    final currentUser = ref.read(authProvider).currentUser;
    final isCashier = currentUser?.isCashier ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kirim & Bagikan Laporan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Pilih format laporan untuk dibagikan melalui Android Share Sheet (WhatsApp, Email, Telegram, dll):',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.successContainer, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.chat_outlined, color: AppColors.success),
              ),
              title: const Text('Ringkasan Teks WhatsApp'),
              subtitle: const Text('Format pesan teks rapi siap kirim ke owner atau grup WhatsApp toko'),
              onTap: () {
                Navigator.of(ctx).pop();
                ShareService.shareSummaryText(_reportData!, isCashier: isCashier);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.dangerContainer, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.danger),
              ),
              title: const Text('Dokumen PDF Resmi'),
              subtitle: const Text('File PDF lengkap dengan logo toko dan tabel ringkasan keuangan'),
              onTap: () {
                Navigator.of(ctx).pop();
                ShareService.sharePdfReport(_reportData!, isCashier: isCashier);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.table_chart_outlined, color: AppColors.primary),
              ),
              title: const Text('Spreadsheet Excel (XLSX)'),
              subtitle: const Text('File Excel multi-sheet berisi data detail transaksi dan pengeluaran'),
              onTap: () {
                Navigator.of(ctx).pop();
                ShareService.shareExcelReport(_reportData!, isCashier: isCashier);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.security, color: Colors.purple),
              ),
              title: const Text('Laporan Lengkap + Riwayat Audit Log'),
              subtitle: const Text('Ringkasan penjualan dan catatan audit aktivitas toko (WhatsApp)'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final logs = await SettingsRepository().getAuditLogs(limit: 15);
                await ShareService.shareFullReportWithAuditLogs(report: _reportData!, auditLogs: logs, isCashier: isCashier);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelTransactionPrompt(String transactionNumber) async {
    final user = ref.read(authProvider).currentUser;
    if (user == null || (!user.isOwner && !user.isManager)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hanya Pemilik atau Manager yang dapat membatalkan transaksi')),
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    bool shouldRestock = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Batalkan Transaksi\n$transactionNumber'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Alasan Pembatalan (Wajib):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(hintText: 'Contoh: Pelanggan salah pesan, pesanan batal dibuat'),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kembalikan Bahan ke Stok', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Hanya centang jika minuman belum diracik dan bahan belum terbuang'),
                value: shouldRestock,
                onChanged: (val) => setModalState(() => shouldRestock = val ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alasan pembatalan wajib diisi')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Batalkan Transaksi'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final trxList = await _posRepo.getTransactions(query: transactionNumber);
        if (trxList.isNotEmpty) {
          await _posRepo.cancelTransaction(
            transactionId: trxList.first.id,
            cancelledByUserId: user.id,
            cancelledByName: user.name,
            cancellationReason: reasonCtrl.text.trim(),
            shouldRestock: shouldRestock,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaksi berhasil dibatalkan'), backgroundColor: AppColors.success),
            );
            _loadReport();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _reportData;
    final currentUser = ref.watch(authProvider).currentUser;
    final isCashier = currentUser?.isCashier ?? false;

    return AppScaffold(
      title: 'Laporan Penjualan & Keuangan',
      currentRoute: '/reports',
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Kirim Laporan',
          onPressed: _showShareOptions,
        ),
      ],
      body: Column(
        children: [
          // Period Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _periodChip('Hari Ini', 'TODAY'),
                  _periodChip('Minggu Ini', 'WEEK'),
                  _periodChip('Bulan Ini', 'MONTH'),
                  _periodChip('Rentang Kustom', 'CUSTOM', onCustomTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (range != null) {
                      _selectedPeriod = 'CUSTOM';
                      _startDate = range.start;
                      _endDate = range.end;
                      _loadReport();
                    }
                  }),
                ],
              ),
            ),
          ),

          // Report Content
          Expanded(
            child: _isLoading || r == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Primary "Kirim Laporan" Button (PROMPT REQUIREMENT)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.share, size: 20),
                            label: const Text('KIRIM LAPORAN (WHATSAPP / PDF / EXCEL)', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _showShareOptions,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Summary Overview Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      r.periodTitle,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${DateFormatter.formatDateShort(r.startDate)} - ${DateFormatter.formatDateShort(r.endDate)}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                _reportRow('Total Omzet Penjualan', CurrencyFormatter.format(r.totalRevenue), isBold: true, fontSize: 16, color: AppColors.primary),
                                _reportRow('Jumlah Transaksi', '${r.totalTransactions} transaksi'),
                                _reportRow('Total Minuman Terjual', '${r.totalItemsSold} cup'),
                                _reportRow('Penjualan Tunai', CurrencyFormatter.format(r.totalCashSales)),
                                _reportRow('Penjualan QRIS', CurrencyFormatter.format(r.totalQrisSales)),
                                if (r.totalDiscounts > 0)
                                  _reportRow('Total Diskon Diberikan', CurrencyFormatter.format(r.totalDiscounts), color: AppColors.danger),
                                if (!isCashier) ...[
                                  const Divider(height: 16),
                                  _reportRow('Total HPP (Bahan Baku)', CurrencyFormatter.format(r.totalCogs), color: AppColors.warning),
                                  _reportRow('Estimasi Laba Kotor', CurrencyFormatter.format(r.grossProfit), isBold: true, color: AppColors.success),
                                  _reportRow('Total Pengeluaran Toko', CurrencyFormatter.format(r.totalExpenses), color: AppColors.danger),
                                  if (r.totalSalaries > 0)
                                    _reportRow('Total Gaji Dibayar', CurrencyFormatter.format(r.totalSalaries), color: AppColors.danger),
                                  const Divider(height: 16),
                                  _reportRow(
                                    'Estimasi Laba Setelah Pengeluaran',
                                    CurrencyFormatter.format(r.netProfitAfterExpenses),
                                    isBold: true,
                                    fontSize: 16,
                                    color: r.netProfitAfterExpenses >= 0 ? AppColors.success : AppColors.danger,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Top Products Card
                        if (r.topProducts.isNotEmpty) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Produk Terlaris dalam Periode Ini', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  const Divider(height: 20),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: r.topProducts.length,
                                    separatorBuilder: (_, __) => const Divider(height: 10),
                                    itemBuilder: (context, index) {
                                      final p = r.topProducts[index];
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${index + 1}. ${p['product_name']}',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                          ),
                                          Text('${p['total_qty']} cup', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          const SizedBox(width: 16),
                                          Text(
                                            CurrencyFormatter.format(p['total_sales'] as num?),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Transaction List with Cancellation Action
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daftar Transaksi (${r.transactions.length})',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const Divider(height: 20),
                                if (r.transactions.isEmpty)
                                  const Center(child: Text('Tidak ada transaksi pada periode ini', style: TextStyle(color: AppColors.textSecondary)))
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: r.transactions.length,
                                    separatorBuilder: (_, __) => const Divider(height: 12),
                                    itemBuilder: (context, index) {
                                      final t = r.transactions[index];
                                      final isCancelled = t['status'] == 'DIBATALKAN';

                                      return Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      t['transaction_number']?.toString() ?? '',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                    if (isCancelled) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                        decoration: BoxDecoration(color: AppColors.dangerContainer, borderRadius: BorderRadius.circular(4)),
                                                        child: const Text('BATAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.danger)),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                Text(
                                                  '${t['created_at']} • Kasir: ${t['cashier_name']} • ${t['payment_method']}',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            CurrencyFormatter.format(t['final_amount'] as num?),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isCancelled ? AppColors.textMuted : AppColors.textPrimary,
                                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          if (!isCancelled)
                                            IconButton(
                                              icon: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
                                              tooltip: 'Batalkan Transaksi',
                                              onPressed: () => _cancelTransactionPrompt(t['transaction_number']),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, String period, {VoidCallback? onCustomTap}) {
    final isSelected = _selectedPeriod == period;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryContainer,
        onSelected: (selected) {
          if (selected) {
            if (period == 'CUSTOM' && onCustomTap != null) {
              onCustomTap();
            } else {
              _setPeriod(period);
            }
          }
        },
      ),
    );
  }

  Widget _reportRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
