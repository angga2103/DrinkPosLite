import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/report_model.dart';
import '../constants/app_constants.dart';
import '../utils/date_formatter.dart';

class ExcelReportService {
  static Future<File> generateSalesReportExcel(SalesReportData report) async {
    final excel = Excel.createExcel();

    // Default sheet is 'Sheet1', rename or use custom sheet
    const sheetName = 'Ringkasan Laporan';
    final Sheet sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // Title & Info
    sheet.appendRow([TextCellValue('LAPORAN PENJUALAN & KEUANGAN - DRINKPOS LITE')]);
    sheet.appendRow([TextCellValue('Toko: ${report.storeName}')]);
    sheet.appendRow([TextCellValue('Periode: ${DateFormatter.formatDateShort(report.startDate)} s/d ${DateFormatter.formatDateShort(report.endDate)}')]);
    sheet.appendRow([TextCellValue('Dibuat: ${DateFormatter.formatDateTime(DateTime.now())}')]);
    sheet.appendRow([TextCellValue('Developer: ${AppConstants.developedByText} (${AppConstants.contactText})')]);
    sheet.appendRow([TextCellValue('')]); // empty line

    // Header Ringkasan
    sheet.appendRow([TextCellValue('METRIK KEUANGAN'), TextCellValue('NILAI')]);
    sheet.appendRow([TextCellValue('Total Omzet Penjualan'), DoubleCellValue(report.totalRevenue)]);
    sheet.appendRow([TextCellValue('Jumlah Transaksi'), IntCellValue(report.totalTransactions)]);
    sheet.appendRow([TextCellValue('Total Cup Terjual'), IntCellValue(report.totalItemsSold)]);
    sheet.appendRow([TextCellValue('Penjualan Tunai'), DoubleCellValue(report.totalCashSales)]);
    sheet.appendRow([TextCellValue('Penjualan QRIS'), DoubleCellValue(report.totalQrisSales)]);
    sheet.appendRow([TextCellValue('Total Diskon'), DoubleCellValue(report.totalDiscounts)]);
    sheet.appendRow([TextCellValue('Total HPP (Bahan Baku)'), DoubleCellValue(report.totalCogs)]);
    sheet.appendRow([TextCellValue('Estimasi Laba Kotor'), DoubleCellValue(report.grossProfit)]);
    sheet.appendRow([TextCellValue('Total Biaya Operasional'), DoubleCellValue(report.totalExpenses)]);
    sheet.appendRow([TextCellValue('Total Gaji Pegawai'), DoubleCellValue(report.totalSalaries)]);
    sheet.appendRow([TextCellValue('Estimasi Laba Bersih'), DoubleCellValue(report.netProfitAfterExpenses)]);
    sheet.appendRow([TextCellValue('')]);

    // Sheet 2: Produk Terlaris
    final Sheet sheetTop = excel['Produk Terlaris'];
    sheetTop.appendRow([TextCellValue('PRODUK TERLARIS')]);
    sheetTop.appendRow([TextCellValue('No'), TextCellValue('Nama Produk'), TextCellValue('Jumlah Cup'), TextCellValue('Total Penjualan')]);
    int no = 1;
    for (final p in report.topProducts) {
      sheetTop.appendRow([
        IntCellValue(no++),
        TextCellValue(p['product_name']?.toString() ?? '-'),
        IntCellValue((p['total_qty'] as num? ?? 0).toInt()),
        DoubleCellValue((p['total_sales'] as num? ?? 0.0).toDouble()),
      ]);
    }

    // Sheet 3: Transaksi
    final Sheet sheetTrx = excel['Daftar Transaksi'];
    sheetTrx.appendRow([TextCellValue('DAFTAR TRANSAKSI')]);
    sheetTrx.appendRow([
      TextCellValue('No. Transaksi'),
      TextCellValue('Waktu'),
      TextCellValue('Kasir'),
      TextCellValue('Metode Bayar'),
      TextCellValue('Total Akhir'),
      TextCellValue('Status'),
    ]);
    for (final t in report.transactions) {
      sheetTrx.appendRow([
        TextCellValue(t['transaction_number']?.toString() ?? '-'),
        TextCellValue(t['created_at']?.toString() ?? '-'),
        TextCellValue(t['cashier_name']?.toString() ?? '-'),
        TextCellValue(t['payment_method']?.toString() ?? '-'),
        DoubleCellValue((t['final_amount'] as num? ?? 0.0).toDouble()),
        TextCellValue(t['status']?.toString() ?? '-'),
      ]);
    }

    // Sheet 4: Pengeluaran
    final Sheet sheetExp = excel['Daftar Pengeluaran'];
    sheetExp.appendRow([TextCellValue('DAFTAR PENGELUARAN')]);
    sheetExp.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Kategori'),
      TextCellValue('Keterangan'),
      TextCellValue('Metode Bayar'),
      TextCellValue('Nominal'),
    ]);
    for (final exp in report.expensesList) {
      sheetExp.appendRow([
        TextCellValue(exp['date']?.toString() ?? '-'),
        TextCellValue(exp['category_name']?.toString() ?? '-'),
        TextCellValue(exp['description']?.toString() ?? '-'),
        TextCellValue(exp['payment_method']?.toString() ?? '-'),
        DoubleCellValue((exp['amount'] as num? ?? 0.0).toDouble()),
      ]);
    }

    // Remove unused 'Sheet1' if exists and different
    if (excel.sheets.containsKey('Sheet1') && sheetName != 'Sheet1') {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal membuat file Excel');

    final tempDir = await getTemporaryDirectory();
    final fileName = 'Laporan_DrinkPOS_${DateFormatter.forFileName(DateTime.now())}.xlsx';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
