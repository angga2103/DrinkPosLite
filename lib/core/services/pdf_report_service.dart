import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../data/models/report_model.dart';
import '../constants/app_constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class PdfReportService {
  static Future<Uint8List> generateSalesReportPdf(SalesReportData report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      report.storeName,
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800),
                    ),
                    pw.Text('Aplikasi: DrinkPOS Lite', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(AppConstants.developedByText, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'LAPORAN KEUANGAN & PENJUALAN',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Periode: ${DateFormatter.formatDateShort(report.startDate)} - ${DateFormatter.formatDateShort(report.endDate)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text('Dibuat: ${DateFormatter.formatDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.teal800),
            pw.SizedBox(height: 12),

            // Financial Metrics Table
            pw.Text('1. Ringkasan Keuangan', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _buildTableRow('Total Omzet Penjualan', CurrencyFormatter.format(report.totalRevenue), isBold: true),
                _buildTableRow('Jumlah Transaksi Berhasil', '${report.totalTransactions} transaksi'),
                _buildTableRow('Total Minuman Terjual', '${report.totalItemsSold} porsi/cup'),
                _buildTableRow('Penerimaan Tunai', CurrencyFormatter.format(report.totalCashSales)),
                _buildTableRow('Penerimaan QRIS', CurrencyFormatter.format(report.totalQrisSales)),
                _buildTableRow('Total Diskon Diberikan', CurrencyFormatter.format(report.totalDiscounts)),
                _buildTableRow('Total HPP (Biaya Bahan Baku)', CurrencyFormatter.format(report.totalCogs)),
                _buildTableRow('Estimasi Laba Kotor', CurrencyFormatter.format(report.grossProfit), isBold: true),
                _buildTableRow('Total Biaya Operasional', CurrencyFormatter.format(report.totalExpenses)),
                _buildTableRow('Total Gaji Pegawai', CurrencyFormatter.format(report.totalSalaries)),
                _buildTableRow(
                  'Estimasi Laba Setelah Pengeluaran',
                  CurrencyFormatter.format(report.netProfitAfterExpenses),
                  isBold: true,
                  bgColor: PdfColors.teal50,
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Top Products
            if (report.topProducts.isNotEmpty) ...[
              pw.Text('2. Produk Terlaris', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildCell('Nama Produk', isHeader: true),
                      _buildCell('Jumlah Cup', isHeader: true, align: pw.TextAlign.right),
                      _buildCell('Total Penjualan', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  ...report.topProducts.map((p) => pw.TableRow(
                        children: [
                          _buildCell(p['product_name']?.toString() ?? '-'),
                          _buildCell('${p['total_qty']} cup', align: pw.TextAlign.right),
                          _buildCell(CurrencyFormatter.format(p['total_sales'] as num?), align: pw.TextAlign.right),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // Note & Disclaimer
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Catatan Penting:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    '1. Pembayaran QRIS diverifikasi secara manual oleh kasir.\n'
                    '2. HPP dihitung berdasarkan resep dan harga pembelian bahan saat transaksi terjadi.\n'
                    '3. Laba yang tercantum adalah estimasi operasional kedai, bukan laporan akuntansi yang diaudit.',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Developer Footer
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('DrinkPOS Lite | Aplikasi Kasir Minuman UMKM', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('${AppConstants.developedByText} | ${AppConstants.contactText}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static pw.TableRow _buildTableRow(String label, String value, {bool isBold = false, PdfColor? bgColor}) {
    return pw.TableRow(
      decoration: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static Future<File> savePdfToFile(Uint8List pdfBytes, String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }
}
