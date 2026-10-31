import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';

class PaymentResult {
  final String paymentMethod;
  final double cashReceived;
  final double qrisAmount;
  final double changeAmount;

  PaymentResult({
    required this.paymentMethod,
    required this.cashReceived,
    required this.qrisAmount,
    required this.changeAmount,
  });
}

class PaymentDialog extends StatefulWidget {
  final double finalAmount;

  const PaymentDialog({super.key, required this.finalAmount});

  static Future<PaymentResult?> show(BuildContext context, double finalAmount) {
    return showModalBottomSheet<PaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentDialog(finalAmount: finalAmount),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _selectedMethod = AppConstants.paymentCash;
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _qrisController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default cash tender to final amount
    _cashController.text = widget.finalAmount.toStringAsFixed(0);
  }

  double get _cashReceived => double.tryParse(_cashController.text.replaceAll('.', '')) ?? 0.0;
  double get _qrisAmount => double.tryParse(_qrisController.text.replaceAll('.', '')) ?? 0.0;

  double get _changeAmount {
    if (_selectedMethod == AppConstants.paymentCash) {
      final change = _cashReceived - widget.finalAmount;
      return change > 0 ? change : 0.0;
    } else if (_selectedMethod == AppConstants.paymentSplit) {
      final remainingAfterQris = widget.finalAmount - _qrisAmount;
      final change = _cashReceived - remainingAfterQris;
      return change > 0 ? change : 0.0;
    }
    return 0.0;
  }

  double get _remainingDeficit {
    if (_selectedMethod == AppConstants.paymentCash) {
      final def = widget.finalAmount - _cashReceived;
      return def > 0 ? def : 0.0;
    } else if (_selectedMethod == AppConstants.paymentSplit) {
      final def = widget.finalAmount - (_cashReceived + _qrisAmount);
      return def > 0 ? def : 0.0;
    }
    return 0.0;
  }

  bool get _isPaymentValid {
    if (_selectedMethod == AppConstants.paymentCash) {
      return _cashReceived >= widget.finalAmount;
    } else if (_selectedMethod == AppConstants.paymentQris) {
      return true; // Cashier confirms QRIS was paid
    } else {
      return (_cashReceived + _qrisAmount) >= widget.finalAmount && _qrisAmount > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Pembayaran Pesanan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  CurrencyFormatter.format(widget.finalAmount),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const Divider(height: 20),

            // Payment Method Selector
            const Text('Pilih Metode Pembayaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMethodTile(AppConstants.paymentCash, 'Tunai (Cash)', Icons.payments_outlined),
                const SizedBox(width: 8),
                _buildMethodTile(AppConstants.paymentQris, 'QRIS', Icons.qr_code_2),
                const SizedBox(width: 8),
                _buildMethodTile(AppConstants.paymentSplit, 'Gabungan', Icons.pie_chart_outline),
              ],
            ),
            const SizedBox(height: 16),

            // Method Specific Inputs
            if (_selectedMethod == AppConstants.paymentCash) ...[
              const Text('Uang Tunai Diterima', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              // Quick Cash Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quickCashChip('Uang Pas', widget.finalAmount),
                  _quickCashChip('Rp 10.000', 10000),
                  _quickCashChip('Rp 20.000', 20000),
                  _quickCashChip('Rp 50.000', 50000),
                  _quickCashChip('Rp 100.000', 100000),
                ],
              ),
            ] else if (_selectedMethod == AppConstants.paymentQris) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryLight),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Konfirmasi Pembayaran QRIS Manual',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tunjukkan QRIS toko Anda kepada pelanggan. Pastikan kasir telah memverifikasi bukti transfer atau notifikasi di aplikasi QRIS toko sebelum menyelesaikan transaksi.',
                      style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedMethod == AppConstants.paymentSplit) ...[
              const Text('Nominal QRIS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _qrisController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(prefixText: 'Rp '),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              const Text('Nominal Tunai', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(prefixText: 'Rp '),
                onChanged: (_) => setState(() {}),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),

            // Calculation Summary (Change or Deficit)
            if (_remainingDeficit > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kekurangan Pembayaran:', style: TextStyle(fontSize: 14, color: AppColors.danger)),
                    Text(
                      CurrencyFormatter.format(_remainingDeficit),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger),
                    ),
                  ],
                ),
              ),

            if (_selectedMethod != AppConstants.paymentQris)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(
                      CurrencyFormatter.format(_changeAmount),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPaymentValid ? AppColors.primary : AppColors.cardBorder,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isPaymentValid
                    ? () {
                        final result = PaymentResult(
                          paymentMethod: _selectedMethod,
                          cashReceived: _selectedMethod == AppConstants.paymentQris ? 0.0 : _cashReceived,
                          qrisAmount: _selectedMethod == AppConstants.paymentQris ? widget.finalAmount : _qrisAmount,
                          changeAmount: _changeAmount,
                        );
                        Navigator.of(context).pop(result);
                      }
                    : null,
                child: const Text('Selesaikan Transaksi & Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTile(String method, String label, IconData icon) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = method;
            if (method == AppConstants.paymentQris) {
              _cashController.text = '0';
              _qrisController.text = widget.finalAmount.toStringAsFixed(0);
            } else if (method == AppConstants.paymentCash) {
              _cashController.text = widget.finalAmount.toStringAsFixed(0);
              _qrisController.text = '0';
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : AppColors.background,
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickCashChip(String label, double amount) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.background,
      side: const BorderSide(color: AppColors.cardBorder),
      onPressed: () {
        setState(() {
          _cashController.text = amount.toStringAsFixed(0);
        });
      },
    );
  }
}
