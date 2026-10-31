import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/store_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/printer_provider.dart';
import '../../../providers/settings_provider.dart';
import '../settings/printer_settings_screen.dart';
import 'pos_screen.dart';

class ReceiptPreviewScreen extends ConsumerWidget {
  final TransactionModel transaction;

  const ReceiptPreviewScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(settingsProvider).store;
    final printerState = ref.watch(printerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Struk Pembayaran'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Bagikan Struk',
            onPressed: () => _shareReceiptText(store),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Success Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  SizedBox(width: 8),
                  Text(
                    'Transaksi Berhasil Disimpan!',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Thermal Paper Preview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Store Logo (jika ada)
                  if (store.logoPath != null && File(store.logoPath!).existsSync()) ...[
                    Image.file(File(store.logoPath!), height: 50, fit: BoxFit.contain),
                    const SizedBox(height: 8),
                  ],

                  // Store Header
                  Text(
                    store.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (store.address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      store.address,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (store.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Telp: ${store.phone}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Divider(height: 24, thickness: 1),

                  // Metadata
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'No: ${transaction.transactionNumber}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormatter.formatDateTime(DateTime.tryParse(transaction.createdAt)),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kasir: ${transaction.cashierName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Metode: ${transaction.paymentMethod}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 1),

                  // Order items
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transaction.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = transaction.items[index];
                      final variantStr = item.variantName != null ? ' (${item.variantName})' : '';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.productName}$variantStr',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(item.subtotal),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${item.quantity} x ${CurrencyFormatter.format(item.unitPrice)}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          for (final mod in item.modifiers)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 2),
                              child: Text(
                                '+ ${mod.name} (${CurrencyFormatter.format(mod.extraPrice)})',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ),
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 2),
                              child: Text(
                                'Catatan: ${item.notes}',
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 24, thickness: 1),

                  // Subtotal & Totals
                  if (transaction.discountAmount > 0) ...[
                    _summaryRow('Subtotal', CurrencyFormatter.format(transaction.totalAmount)),
                    _summaryRow('Diskon Promo', '-${CurrencyFormatter.format(transaction.discountAmount)}', isDiscount: true),
                  ],
                  _summaryRow(
                    'TOTAL',
                    CurrencyFormatter.format(transaction.finalAmount),
                    isBold: true,
                    fontSize: 16,
                  ),

                  if (transaction.paymentMethod == AppConstants.paymentCash || transaction.paymentMethod == AppConstants.paymentSplit) ...[
                    const SizedBox(height: 6),
                    _summaryRow('Tunai Diterima', CurrencyFormatter.format(transaction.cashReceived > 0 ? transaction.cashReceived : transaction.finalAmount)),
                    _summaryRow('Kembalian', CurrencyFormatter.format(transaction.changeAmount)),
                  ],

                  if (transaction.paymentMethod == AppConstants.paymentQris || transaction.paymentMethod == AppConstants.paymentSplit) ...[
                    const SizedBox(height: 6),
                    _summaryRow('Nominal QRIS', CurrencyFormatter.format(transaction.qrisAmount > 0 ? transaction.qrisAmount : transaction.finalAmount)),
                  ],

                  const Divider(height: 24, thickness: 1),

                  // Footer Message
                  if (store.receiptFooter.isNotEmpty)
                    Text(
                      store.receiptFooter,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 6),
                  const Text(
                    AppConstants.developedByText,
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons: Print & New Order
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                      printerState.isConnected ? Icons.print : Icons.print_disabled,
                      color: printerState.isConnected ? AppColors.primary : AppColors.secondary,
                    ),
                    label: Text(printerState.isConnected ? 'Cetak Struk' : 'Atur Printer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      if (!printerState.isConnected) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                        );
                      } else {
                        final freshStore = await ref.read(settingsRepositoryProvider).getStore();
                        final success = await ref.read(printerProvider.notifier).printReceipt(
                              store: freshStore,
                              transaction: transaction,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Struk sedang dicetak...' : 'Gagal mencetak struk'),
                              backgroundColor: success ? AppColors.success : AppColors.danger,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Transaksi Baru'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const PosScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, bool isDiscount = false, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _shareReceiptText(StoreModel store) {
    final buffer = StringBuffer();
    buffer.writeln('🧾 *STRUK PEMBAYARAN*');
    buffer.writeln('*${store.name}*');
    if (store.phone.isNotEmpty) buffer.writeln('Telp: ${store.phone}');
    buffer.writeln('--------------------------------');
    buffer.writeln('No: ${transaction.transactionNumber}');
    buffer.writeln('Waktu: ${DateFormatter.formatDateTime(DateTime.tryParse(transaction.createdAt))}');
    buffer.writeln('Kasir: ${transaction.cashierName}');
    buffer.writeln('--------------------------------');

    for (final item in transaction.items) {
      final v = item.variantName != null ? ' (${item.variantName})' : '';
      buffer.writeln('${item.productName}$v');
      buffer.writeln('  ${item.quantity} x ${CurrencyFormatter.format(item.unitPrice)} = ${CurrencyFormatter.format(item.subtotal)}');
      for (final mod in item.modifiers) {
        buffer.writeln('  + ${mod.name}');
      }
    }

    buffer.writeln('--------------------------------');
    if (transaction.discountAmount > 0) {
      buffer.writeln('Subtotal: ${CurrencyFormatter.format(transaction.totalAmount)}');
      buffer.writeln('Diskon: -${CurrencyFormatter.format(transaction.discountAmount)}');
    }
    buffer.writeln('*TOTAL: ${CurrencyFormatter.format(transaction.finalAmount)}*');
    buffer.writeln('Metode: ${transaction.paymentMethod}');
    if (transaction.changeAmount > 0) {
      buffer.writeln('Kembalian: ${CurrencyFormatter.format(transaction.changeAmount)}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('${AppConstants.developedByText}');

    Share.share(buffer.toString(), subject: 'Struk Pembayaran ${transaction.transactionNumber}');
  }
}
