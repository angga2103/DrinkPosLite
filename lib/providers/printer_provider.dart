import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../core/services/printer_service.dart';
import '../data/models/store_model.dart';
import '../data/models/transaction_model.dart';

class PrinterState {
  final bool isConnected;
  final String? connectedMac;
  final List<BluetoothInfo> availableDevices;
  final bool isScanning;
  final PaperSize paperSize;
  final String? errorMessage;

  PrinterState({
    this.isConnected = false,
    this.connectedMac,
    this.availableDevices = const [],
    this.isScanning = false,
    this.paperSize = PaperSize.mm58,
    this.errorMessage,
  });

  PrinterState copyWith({
    bool? isConnected,
    String? connectedMac,
    List<BluetoothInfo>? availableDevices,
    bool? isScanning,
    PaperSize? paperSize,
    String? errorMessage,
    bool clearMac = false,
  }) {
    return PrinterState(
      isConnected: isConnected ?? this.isConnected,
      connectedMac: clearMac ? null : (connectedMac ?? this.connectedMac),
      availableDevices: availableDevices ?? this.availableDevices,
      isScanning: isScanning ?? this.isScanning,
      paperSize: paperSize ?? this.paperSize,
      errorMessage: errorMessage,
    );
  }
}

class PrinterNotifier extends StateNotifier<PrinterState> {
  final PrinterService _service = PrinterService.instance;

  PrinterNotifier() : super(PrinterState()) {
    _initPrinter();
  }

  Future<void> _initPrinter() async {
    await scanDevices();
  }

  Future<bool> openNativeBluetoothSettings() async {
    return await _service.openNativeBluetoothSettings();
  }

  Future<bool> requestPermission() async {
    final granted = await _service.requestBluetoothPermission();
    if (granted) {
      await scanDevices();
    }
    return granted;
  }

  void setPaperSize(PaperSize size) {
    _service.setPaperSize(size);
    state = state.copyWith(paperSize: size);
  }

  Future<void> scanDevices() async {
    state = state.copyWith(isScanning: true);
    try {
      final devices = await _service.getPairedDevices();
      final isConn = await _service.checkConnectionStatus();
      state = state.copyWith(
        availableDevices: devices,
        isConnected: isConn,
        connectedMac: isConn ? _service.connectedMac : null,
        isScanning: false,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString(), isScanning: false);
    }
  }

  Future<bool> connect(String macAddress) async {
    final success = await _service.connect(macAddress);
    if (success) {
      state = state.copyWith(isConnected: true, connectedMac: macAddress);
    } else {
      state = state.copyWith(isConnected: false, clearMac: true, errorMessage: 'Gagal terhubung ke printer. Pastikan printer menyala & alamat MAC sesuai.');
    }
    return success;
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    state = state.copyWith(isConnected: false, clearMac: true);
  }

  Future<bool> testPrint(StoreModel store) async {
    return await _service.printTestReceipt(store);
  }

  Future<bool> printReceipt({
    required StoreModel store,
    required TransactionModel transaction,
  }) async {
    return await _service.printReceipt(store: store, transaction: transaction);
  }
}

final printerProvider = StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  return PrinterNotifier();
});
