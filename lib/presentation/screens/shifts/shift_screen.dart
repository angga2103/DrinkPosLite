import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/shift_model.dart';
import '../../../data/repositories/shift_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/shift_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state_view.dart';

class ShiftScreen extends ConsumerStatefulWidget {
  const ShiftScreen({super.key});

  @override
  ConsumerState<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends ConsumerState<ShiftScreen> {
  final ShiftRepository _repo = ShiftRepository();
  List<ShiftModel> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _repo.getShiftHistory();
    await ref.read(shiftProvider.notifier).loadCurrentShift();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  void _showOpenShiftDialog() {
    final user = ref.read(authProvider).currentUser;
    final cashCtrl = TextEditingController(text: '100000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buka Shift Kasir Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kasir Bertugas: ${user?.name ?? "Kasir"}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Modal Kas Awal di Laci (Rp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: cashCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(prefixText: 'Rp '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final initial = double.tryParse(cashCtrl.text.replaceAll('.', '')) ?? 0.0;
              final ok = await ref.read(shiftProvider.notifier).openShift(
                    userId: user?.id ?? 'usr_cashier',
                    userName: user?.name ?? 'Kasir',
                    initialCash: initial,
                  );
              if (ok && mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shift berhasil dibuka!'), backgroundColor: AppColors.success),
                );
                _loadHistory();
              }
            },
            child: const Text('Buka Shift'),
          ),
        ],
      ),
    );
  }

  void _showCloseShiftDialog(ShiftModel shift) {
    final user = ref.read(authProvider).currentUser;
    final expected = shift.initialCash + shift.totalCashSales - shift.totalCashExpenses;
    final actualCtrl = TextEditingController(text: expected.toStringAsFixed(0));
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final actual = double.tryParse(actualCtrl.text.replaceAll('.', '')) ?? 0.0;
          final diff = actual - expected;

          return AlertDialog(
            title: const Text('Tutup Shift & Hitung Kas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        _dialogRow('Kas Awal', CurrencyFormatter.format(shift.initialCash)),
                        _dialogRow('Penjualan Tunai (+)', CurrencyFormatter.format(shift.totalCashSales), color: AppColors.success),
                        _dialogRow('Pengeluaran Kas (-)', CurrencyFormatter.format(shift.totalCashExpenses), color: AppColors.danger),
                        const Divider(),
                        _dialogRow('Kas yang Seharusnya Ada', CurrencyFormatter.format(expected), isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Kas Fisik Sebenarnya di Laci', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: actualCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(prefixText: 'Rp '),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Selisih Kas:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${diff >= 0 ? "+" : ""}${CurrencyFormatter.format(diff)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: diff == 0 ? AppColors.success : (diff > 0 ? AppColors.info : AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Catatan Selisih (Jika ada)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () async {
                  final ok = await ref.read(shiftProvider.notifier).closeShift(
                        actualCash: actual,
                        differenceNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                        userId: user?.id ?? 'usr_cashier',
                        userName: user?.name ?? 'Kasir',
                      );
                  if (ok && mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shift berhasil ditutup!'), backgroundColor: AppColors.success),
                    );
                    _loadHistory();
                  }
                },
                child: const Text('Tutup Shift Sekarang'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dialogRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shiftState = ref.watch(shiftProvider);
    final activeShift = shiftState.currentShift;

    return AppScaffold(
      title: 'Shift & Kas Laci',
      currentRoute: '/shifts',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Shift Card or Open Shift Prompt
                  if (activeShift != null && activeShift.isOpen) ...[
                    Card(
                      color: AppColors.primaryContainer.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('SHIFT AKTIF SEDANG BERJALAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark)),
                                  ],
                                ),
                                Text('Kasir: ${activeShift.userName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text('Mulai: ${DateFormatter.formatDateTime(DateTime.tryParse(activeShift.startTime))}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const Divider(height: 20),

                            _metricRow('Kas Awal di Laci', CurrencyFormatter.format(activeShift.initialCash)),
                            _metricRow('Penjualan Tunai (+)', CurrencyFormatter.format(activeShift.totalCashSales), color: AppColors.success),
                            _metricRow('Pengeluaran Kas (-)', CurrencyFormatter.format(activeShift.totalCashExpenses), color: AppColors.danger),
                            const Divider(height: 14),
                            _metricRow(
                              'Kas yang Seharusnya Ada di Laci',
                              CurrencyFormatter.format(activeShift.calculateExpectedCash()),
                              isBold: true,
                              fontSize: 15,
                            ),

                            const Divider(height: 14),
                            _metricRow(
                              'Penerimaan QRIS (Non-Fisik)',
                              CurrencyFormatter.format(activeShift.totalQrisSales),
                              color: const Color(0xFF7C3AED),
                              subtitle: 'Tercatat terpisah di rekening bank, tidak dicampur kas fisik',
                            ),

                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.lock_clock),
                                label: const Text('Tutup Shift & Hitung Kas Fisik'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                onPressed: () => _showCloseShiftDialog(activeShift),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.work_off_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 10),
                            const Text('Tidak Ada Shift yang Sedang Berjalan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text(
                              'Buka shift kasir terlebih dahulu untuk mencatat kas awal laci dan memonitor selisih penjualan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Buka Shift Sekarang'),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                              onPressed: _showOpenShiftDialog,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Text('Riwayat Shift & Rekap Kasir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  if (_history.isEmpty)
                    const EmptyStateView(
                      icon: Icons.history,
                      title: 'Belum Ada Riwayat Shift',
                      message: 'Rekap pembukaan dan penutupan shift kasir akan tampil di sini.',
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final s = _history[index];
                        final isClosed = s.status == 'CLOSED';
                        final diff = s.cashDifference ?? 0.0;

                        return Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Kasir: ${s.userName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isClosed ? AppColors.background : AppColors.successContainer,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: isClosed ? AppColors.cardBorder : AppColors.success),
                                      ),
                                      child: Text(
                                        isClosed ? 'SHIFT SELESAI' : 'SEDANG BERJALAN',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isClosed ? AppColors.textSecondary : AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mulai: ${DateFormatter.formatDateTime(DateTime.tryParse(s.startTime))}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                if (s.endTime != null)
                                  Text(
                                    'Selesai: ${DateFormatter.formatDateTime(DateTime.tryParse(s.endTime!))}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                const Divider(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Penjualan Tunai: ${CurrencyFormatter.format(s.totalCashSales)}', style: const TextStyle(fontSize: 12)),
                                    Text('QRIS: ${CurrencyFormatter.format(s.totalQrisSales)}', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                if (isClosed) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Kas Fisik: ${CurrencyFormatter.format(s.actualCash)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text(
                                        'Selisih: ${diff >= 0 ? "+" : ""}${CurrencyFormatter.format(diff)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: diff == 0 ? AppColors.success : (diff > 0 ? AppColors.info : AppColors.danger),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (s.differenceNote != null && s.differenceNote!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text('Ket. Selisih: ${s.differenceNote}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
                                    ),
                                ],
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

  Widget _metricRow(String label, String value, {Color? color, bool isBold = false, double fontSize = 13, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
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
          if (subtitle != null)
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
