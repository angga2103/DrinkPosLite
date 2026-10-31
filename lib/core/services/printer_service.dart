import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../data/models/store_model.dart';
import '../../data/models/transaction_model.dart';
import '../constants/app_constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._internal();
  PrinterService._internal();

  static const MethodChannel _nativeChannel = MethodChannel('com.ansorstudi.drinkpos_lite/device');

  bool _isConnected = false;
  String? _connectedMac;
  PaperSize _paperSize = PaperSize.mm58;

  bool get isConnected => _isConnected;
  String? get connectedMac => _connectedMac;
  PaperSize get paperSize => _paperSize;

  void setPaperSize(PaperSize size) {
    _paperSize = size;
  }

  Future<bool> openNativeBluetoothSettings() async {
    try {
      await _nativeChannel.invokeMethod('openBluetoothSettings');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestBluetoothPermission() async {
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  Future<List<BluetoothInfo>> getPairedDevices() async {
    try {
      // 1. Prompt and ensure Bluetooth runtime permissions on Android 12+
      await PrintBluetoothThermal.isPermissionBluetoothGranted;

      final bool bluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!bluetoothEnabled) return [];
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (_) {
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    try {
      // Ensure permissions before connect call
      await PrintBluetoothThermal.isPermissionBluetoothGranted;
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress.trim());
      _isConnected = result;
      if (result) {
        _connectedMac = macAddress.trim();
      }
      return result;
    } catch (_) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> checkConnectionStatus() async {
    try {
      final status = await PrintBluetoothThermal.connectionStatus;
      _isConnected = status;
      return status;
    } catch (_) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _isConnected = false;
      _connectedMac = null;
      return result;
    } catch (_) {
      return false;
    }
  }

  int get _maxCharsPerLine => _paperSize == PaperSize.mm58 ? 32 : 48;

  String _formatTwoColumns(String left, String right, {int? maxChars}) {
    final limit = maxChars ?? _maxCharsPerLine;
    final totalLen = left.length + right.length;
    if (totalLen >= limit) {
      final maxLeft = limit - right.length - 1;
      if (maxLeft > 0 && left.length > maxLeft) {
        left = left.substring(0, maxLeft);
      }
    }
    final spaces = limit - left.length - right.length;
    return left + (' ' * (spaces > 0 ? spaces : 1)) + right;
  }

  String _dividerLine() {
    return '-' * _maxCharsPerLine;
  }

  Future<List<int>> _getLogoBytes(String? logoPath, Generator generator) async {
    if (logoPath == null || logoPath.isEmpty) return [];
    try {
      final file = File(logoPath);
      if (!await file.exists()) return [];
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return [];

      // Ukuran optimal printer thermal 58mm (max 384 dot) / 80mm (max 576 dot)
      final targetWidth = _paperSize == PaperSize.mm58 ? 240 : 360;
      img.Image processed = decoded;
      if (processed.width > targetWidth) {
        processed = img.copyResize(processed, width: targetWidth);
      }

      // Konversi ke grayscale untuk kejernihan cetak thermal
      processed = img.grayscale(processed);

      // Gunakan imageRaster (GS v 0) - standar universal printer thermal Bluetooth
      return generator.imageRaster(
        processed,
        align: PosAlign.center,
        highDensityHorizontal: true,
        highDensityVertical: true,
      );
    } catch (_) {
      return [];
    }
  }

  Future<bool> printTestReceipt(StoreModel store) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      List<int> bytes = [];

      bytes += generator.reset();

      // Logo Toko (jika ada)
      bytes += await _getLogoBytes(store.logoPath, generator);

      // Nama Toko (Font normal bold agar tidak terpotong ke bawah)
      bytes += generator.text(
        store.name,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );

      // Header Toko
      if (store.receiptHeader.isNotEmpty) {
        for (final line in store.receiptHeader.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            bytes += generator.text(trimmed, styles: const PosStyles(align: PosAlign.center));
          }
        }
      }

      // Alamat Toko
      if (store.address.isNotEmpty) {
        for (final line in store.address.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            bytes += generator.text(trimmed, styles: const PosStyles(align: PosAlign.center));
          }
        }
      }

      // No Telp Toko
      if (store.phone.isNotEmpty) {
        bytes += generator.text('Telp: ${store.phone}', styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.text(_dividerLine(), styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('TES PRINTER THERMAL', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('Status: Berhasil Terhubung!', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(DateFormatter.formatDateTime(DateTime.now()), styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(_dividerLine(), styles: const PosStyles(align: PosAlign.center));

      bytes += generator.text(AppConstants.developedByText, styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB));
      bytes += generator.text(AppConstants.contactText, styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB));

      // Hemat kertas: Cukup 1 feed pendek
      bytes += generator.feed(1);

      final res = await PrintBluetoothThermal.writeBytes(bytes);
      return res;
    } catch (_) {
      return false;
    }
  }

  Future<bool> printReceipt({
    required StoreModel store,
    required TransactionModel transaction,
  }) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      List<int> bytes = [];

      bytes += generator.reset();

      // 1. Logo Toko (jika ada)
      bytes += await _getLogoBytes(store.logoPath, generator);

      // 2. Nama Toko (Bold, teks normal rapi tanpa terpotong suku kata)
      bytes += generator.text(
        store.name,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );

      // 3. Header Toko
      if (store.receiptHeader.isNotEmpty) {
        for (final line in store.receiptHeader.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            bytes += generator.text(trimmed, styles: const PosStyles(align: PosAlign.center));
          }
        }
      }

      // 4. Alamat Toko
      if (store.address.isNotEmpty) {
        for (final line in store.address.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            bytes += generator.text(trimmed, styles: const PosStyles(align: PosAlign.center));
          }
        }
      }

      // 5. Nomor Telepon Toko
      if (store.phone.isNotEmpty) {
        bytes += generator.text('Telp: ${store.phone}', styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.text(_dividerLine(), styles: const PosStyles(align: PosAlign.center));

      // 6. Informasi Transaksi (2 baris rapi terformat pas kolom)
      final dt = DateTime.tryParse(transaction.createdAt) ?? DateTime.now();
      final cleanCashier = transaction.cashierName.replaceAll(RegExp(r'\(.*?\)'), '').trim();

      bytes += generator.text(
        _formatTwoColumns('No: ${transaction.transactionNumber}', DateFormatter.formatTime(dt)),
      );
      bytes += generator.text(
        _formatTwoColumns('Tgl: ${DateFormatter.formatDateShort(dt)}', 'Kasir: $cleanCashier'),
      );

      bytes += generator.text(_dividerLine(), styles: const PosStyles(align: PosAlign.center));

      // 7. Daftar Produk & Modifikasi
      for (final item in transaction.items) {
        final variantText = item.variantName != null && item.variantName!.isNotEmpty ? ' (${item.variantName})' : '';
        bytes += generator.text('${item.productName}$variantText', styles: const PosStyles(bold: true));

        // Format: '1 x Rp 14.000' di kiri, 'Rp 14.000' di kanan — pas 1 baris tidak melipat nominal
        final qtyPrice = '${item.quantity} x ${CurrencyFormatter.format(item.unitPrice)}';
        final subtotalStr = CurrencyFormatter.format(item.subtotal);
        bytes += generator.text(_formatTwoColumns(qtyPrice, subtotalStr));

        // Topping / Pilihan rasa (font kecil hemat ruang)
        for (final mod in item.modifiers) {
          final extraPriceStr = mod.extraPrice > 0 ? ' (+${CurrencyFormatter.format(mod.extraPrice)})' : '';
          bytes += generator.text('  * ${mod.name}$extraPriceStr', styles: const PosStyles(fontType: PosFontType.fontB));
        }

        // Catatan khusus
        if (item.notes != null && item.notes!.trim().isNotEmpty) {
          bytes += generator.text('  Catatan: ${item.notes!.trim()}', styles: const PosStyles(fontType: PosFontType.fontB));
        }
      }

      bytes += generator.text(_dividerLine(), styles: const PosStyles(align: PosAlign.center));

      // 8. Subtotal & Diskon
      if (transaction.discountAmount > 0) {
        bytes += generator.text(_formatTwoColumns('Subtotal', CurrencyFormatter.format(transaction.totalAmount)));
        bytes += generator.text(_formatTwoColumns('Diskon', '-${CurrencyFormatter.format(transaction.discountAmount)}'));
      }

      // 9. TOTAL PEMBAYARAN (Bold jelas 1 baris tanpa terpotong)
      bytes += generator.text(
        _formatTwoColumns('TOTAL', CurrencyFormatter.format(transaction.finalAmount)),
        styles: const PosStyles(bold: true),
      );

      // 10. Rincian Metode Bayar & Kembalian
      bytes += generator.text(
        _formatTwoColumns('Metode Bayar', transaction.paymentMethod),
      );

      if (transaction.paymentMethod == AppConstants.paymentCash || transaction.paymentMethod == AppConstants.paymentSplit) {
        final cashTender = transaction.cashReceived > 0 ? transaction.cashReceived : transaction.finalAmount;
        bytes += generator.text(_formatTwoColumns('Tunai Diterima', CurrencyFormatter.format(cashTender)));
        bytes += generator.text(_formatTwoColumns('Kembalian', CurrencyFormatter.format(transaction.changeAmount)));
      }

      if (transaction.paymentMethod == AppConstants.paymentQris || transaction.paymentMethod == AppConstants.paymentSplit) {
        final qAmount = transaction.qrisAmount > 0 ? transaction.qrisAmount : transaction.finalAmount;
        bytes += generator.text(_formatTwoColumns('Nominal QRIS', CurrencyFormatter.format(qAmount)));
      }

      bytes += generator.text(_dividerLine(), styles: const PosStyles(align: PosAlign.center));

      // 11. Footer Struk
      if (store.receiptFooter.isNotEmpty) {
        for (final line in store.receiptFooter.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            bytes += generator.text(trimmed, styles: const PosStyles(align: PosAlign.center));
          }
        }
      }

      // Identitas Developer Resmi
      bytes += generator.text(AppConstants.developedByText, styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB));

      // Hemat kertas maksimal: Cukup 1 feed pendek agar tidak boros kertas
      bytes += generator.feed(1);

      final res = await PrintBluetoothThermal.writeBytes(bytes);
      return res;
    } catch (_) {
      return false;
    }
  }
}
