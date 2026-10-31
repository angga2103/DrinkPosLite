import 'package:share_plus/share_plus.dart';
import '../../data/models/audit_model.dart';
import '../../data/models/ingredient_model.dart';
import '../../data/models/report_model.dart';
import '../constants/app_constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import 'excel_report_service.dart';
import 'pdf_report_service.dart';

class ShareService {
  static String formatWhatsAppSummary(SalesReportData report, {bool isCashier = false}) {
    final buffer = StringBuffer();
    buffer.writeln('📊 *LAPORAN PENJUALAN — DRINKPOS LITE*');
    buffer.writeln('🏪 *${report.storeName}*');
    buffer.writeln('📅 Periode: ${DateFormatter.formatDateShort(report.startDate)} s/d ${DateFormatter.formatDateShort(report.endDate)}');
    buffer.writeln('⏰ Dibuat: ${DateFormatter.formatDateTime(DateTime.now())}');
    buffer.writeln('-----------------------------------');
    buffer.writeln('💰 *Total Omzet:* ${CurrencyFormatter.format(report.totalRevenue)}');
    buffer.writeln('🧾 *Jumlah Transaksi:* ${report.totalTransactions}');
    buffer.writeln('🥤 *Total Cup Terjual:* ${report.totalItemsSold}');
    buffer.writeln('💵 *Penjualan Tunai:* ${CurrencyFormatter.format(report.totalCashSales)}');
    buffer.writeln('📱 *Penjualan QRIS:* ${CurrencyFormatter.format(report.totalQrisSales)}');
    if (report.totalDiscounts > 0) {
      buffer.writeln('🏷️ *Total Diskon:* ${CurrencyFormatter.format(report.totalDiscounts)}');
    }
    // Sembunyikan HPP, Laba Kotor, dan Laba Bersih jika diakses oleh Kasir (Point 3)
    if (!isCashier) {
      buffer.writeln('📦 *Total HPP (Bahan):* ${CurrencyFormatter.format(report.totalCogs)}');
      buffer.writeln('📈 *Estimasi Laba Kotor:* ${CurrencyFormatter.format(report.grossProfit)}');
      buffer.writeln('💸 *Pengeluaran Toko:* ${CurrencyFormatter.format(report.totalExpenses)}');
      if (report.totalSalaries > 0) {
        buffer.writeln('💼 *Gaji Pegawai:* ${CurrencyFormatter.format(report.totalSalaries)}');
      }
      buffer.writeln('✨ *Est. Laba Bersih:* ${CurrencyFormatter.format(report.netProfitAfterExpenses)}');
    }

    if (report.topProducts.isNotEmpty) {
      buffer.writeln('-----------------------------------');
      buffer.writeln('🏆 *PRODUK TERLARIS:*');
      int rank = 1;
      for (final p in report.topProducts.take(5)) {
        buffer.writeln('$rank. ${p['product_name']} (${p['total_qty']} cup) - ${CurrencyFormatter.format(p['total_sales'] as num?)}');
        rank++;
      }
    }

    buffer.writeln('-----------------------------------');
    buffer.writeln('💡 *Catatan:*');
    buffer.writeln('• QRIS diverifikasi manual oleh kasir.');
    buffer.writeln('• Laba adalah estimasi operasional kedai.');
    buffer.writeln('-----------------------------------');
    buffer.writeln(AppConstants.developedByText);
    buffer.writeln(AppConstants.contactText);

    return buffer.toString();
  }

  static String _formatActionSimple(String action) {
    switch (action.toUpperCase()) {
      case 'TRANSACTION_CANCEL':
      case 'CANCEL_TRANSACTION':
        return 'Pembatalan Transaksi/Nota';
      case 'UPDATE_PRODUCT_PRICE':
        return 'Perubahan Harga Menu';
      case 'DELETE_PRODUCT':
        return 'Penghapusan Menu Produk';
      case 'STOCK_ADJUSTMENT':
        return 'Penyesuaian Stok Manual';
      case 'STOCK_OPNAME':
        return 'Stok Opname Bahan';
      case 'UPDATE_PURCHASE_PRICE':
        return 'Pembaruan Harga Beli';
      case 'CREATE_PURCHASE':
        return 'Pembelian Bahan Masuk';
      case 'SYNC_PACKAGE_APPLIED':
        return 'Update Resep/Stok via WhatsApp';
      case 'STORE_PROFILE_UPDATE':
      case 'STORE_UPDATE':
        return 'Pembaruan Profil Toko & Logo';
      case 'CHANGE_PIN':
        return 'Perubahan PIN Pegawai';
      case 'USER_LOCKED':
        return 'Akun Terkunci (Salah PIN)';
      case 'UNLOCK_USER':
        return 'Buka Kunci Akun';
      case 'DELETE_EMPLOYEE':
        return 'Hapus Profil Pegawai';
      case 'SAVE_EMPLOYEE':
        return 'Ubah Data/Hak Akses Pegawai';
      case 'CREATE_BACKUP':
        return 'Pencadangan Database (Backup)';
      case 'RESTORE_BACKUP':
        return 'Pemulihan Database (Restore)';
      case 'OPEN_SHIFT':
        return 'Buka Kasir/Shift';
      case 'CLOSE_SHIFT':
        return 'Tutup Kasir/Shift';
      case 'CANCEL_EXPENSE':
        return 'Pembatalan Pengeluaran';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  static Future<void> shareFullReportWithAuditLogs({
    required SalesReportData report,
    required List<AuditLogModel> auditLogs,
    bool isCashier = false,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln(formatWhatsAppSummary(report, isCashier: isCashier));
    buffer.writeln('');
    buffer.writeln('🔐 *RIWAYAT AUDIT LOG AKTIVITAS SENSITIF*');
    buffer.writeln('-----------------------------------');
    if (auditLogs.isEmpty) {
      buffer.writeln('Tidak ada catatan aktivitas sensitif.');
    } else {
      int count = 1;
      for (final log in auditLogs.take(15)) {
        final act = _formatActionSimple(log.action);
        final time = DateFormatter.formatDateTime(DateTime.tryParse(log.createdAt));
        buffer.writeln('$count. *$act* ($time)');
        buffer.writeln('   Oleh: ${log.userName ?? "Sistem"}');
        if (log.reason != null && log.reason!.isNotEmpty) {
          buffer.writeln('   Ket: ${log.reason}');
        }
        if (log.oldValue != null && log.newValue != null) {
          buffer.writeln('   Perubahan: ${log.oldValue} -> ${log.newValue}');
        }
        count++;
      }
    }
    buffer.writeln('-----------------------------------');
    buffer.writeln('Dikirim dari Aplikasi DrinkPOS Lite');

    await Share.share(
      buffer.toString(),
      subject: 'Laporan Lengkap & Audit Log - ${report.storeName}',
    );
  }

  static String formatLowStockProcurementMessage({
    required List<IngredientModel> items,
    required String storeName,
    String? storePhone,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('⚠️ *PESANAN PENGADAAN BAHAN BAKU*');
    buffer.writeln('🏪 *Kedai: $storeName*');
    if (storePhone != null && storePhone.isNotEmpty) {
      buffer.writeln('📞 Kontak: $storePhone');
    }
    buffer.writeln('📅 Tanggal: ${DateFormatter.formatDateTime(DateTime.now())}');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Halo Supplier / Bagian Pengadaan,');
    buffer.writeln('Berikut rincian bahan baku kedai kami yang sudah menipis dan perlu segera dikirim:');
    buffer.writeln('');

    double totalEstCost = 0.0;
    int index = 1;

    for (final item in items) {
      final suggestQty = (item.minimumStock * 2 > item.currentStock)
          ? ((item.minimumStock * 2) - item.currentStock)
          : (item.minimumStock * 2);
      final estItemCost = suggestQty * item.costPerUnit;
      totalEstCost += estItemCost;

      buffer.writeln('$index. *${item.name}*');
      buffer.writeln('   • Sisa Stok: ${item.currentStock.toStringAsFixed(0)} ${item.unit}');
      buffer.writeln('   • Batas Minimal: ${item.minimumStock.toStringAsFixed(0)} ${item.unit}');
      buffer.writeln('   • Rekomendasi Pesan: ${suggestQty.toStringAsFixed(0)} ${item.unit}');
      if (item.costPerUnit > 0) {
        buffer.writeln('   • Est. Harga: ${CurrencyFormatter.format(estItemCost)}');
      }
      buffer.writeln('');
      index++;
    }

    buffer.writeln('-----------------------------------');
    if (totalEstCost > 0) {
      buffer.writeln('💰 *Total Estimasi Pembelian:* ${CurrencyFormatter.format(totalEstCost)}');
    }
    buffer.writeln('Mohon konfirmasi ketersediaan dan perkiraan jadwal pengiriman.');
    buffer.writeln('Terima kasih!');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Dibuat otomatis via DrinkPOS Lite');
    buffer.writeln('${AppConstants.developedByText} (${AppConstants.contactText})');

    return buffer.toString();
  }

  static Future<void> shareSummaryText(SalesReportData report, {bool isCashier = false}) async {
    final text = formatWhatsAppSummary(report, isCashier: isCashier);
    await Share.share(
      text,
      subject: 'Laporan Penjualan ${report.storeName}',
    );
  }

  static Future<void> sharePdfReport(SalesReportData report, {bool isCashier = false}) async {
    final pdfBytes = await PdfReportService.generateSalesReportPdf(report);
    final fileName = 'Laporan_DrinkPOS_${DateFormatter.forFileName(DateTime.now())}.pdf';
    final file = await PdfReportService.savePdfToFile(pdfBytes, fileName);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf', name: fileName)],
      text: formatWhatsAppSummary(report, isCashier: isCashier),
      subject: 'Laporan PDF ${report.storeName}',
    );
  }

  static Future<void> shareExcelReport(SalesReportData report, {bool isCashier = false}) async {
    final file = await ExcelReportService.generateSalesReportExcel(report);

    await Share.shareXFiles(
      [
        XFile(file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: file.path.split('/').last)
      ],
      text: formatWhatsAppSummary(report, isCashier: isCashier),
      subject: 'Laporan Excel ${report.storeName}',
    );
  }

  static Future<void> shareLowStockProcurementWhatsApp({
    required List<IngredientModel> items,
    required String storeName,
    String? storePhone,
  }) async {
    final text = formatLowStockProcurementMessage(
      items: items,
      storeName: storeName,
      storePhone: storePhone,
    );
    await Share.share(
      text,
      subject: 'Pesanan Pengadaan Bahan - $storeName',
    );
  }
}
