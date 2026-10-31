import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/printer_provider.dart';
import '../../../providers/settings_provider.dart';
import '../dashboard/dashboard_screen.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  final TextEditingController _macController = TextEditingController();
  bool _isConnectingManual = false;

  @override
  void dispose() {
    _macController.dispose();
    super.dispose();
  }

  Future<void> _connectManual() async {
    final mac = _macController.text.trim();
    if (mac.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan alamat MAC printer (contoh: 66:02:BD:06:18:7B)')),
      );
      return;
    }

    setState(() => _isConnectingManual = true);
    final ok = await ref.read(printerProvider.notifier).connect(mac);
    setState(() => _isConnectingManual = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Berhasil terhubung ke printer $mac!' : 'Gagal menghubungkan. Pastikan printer menyala & dalam jangkauan Bluetooth.'),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  void _returnToDashboard(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerState = ref.watch(printerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _returnToDashboard(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Kembali ke Dashboard',
            onPressed: () => _returnToDashboard(context),
          ),
          title: const Text('Pengaturan Printer Thermal'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.dashboard_outlined, size: 16),
              label: const Text('Dashboard'),
              onPressed: () => _returnToDashboard(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Pindai Ulang',
              onPressed: () => ref.read(printerProvider.notifier).scanDevices(),
            ),
          ],
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: printerState.isConnected ? AppColors.successContainer : AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: printerState.isConnected ? AppColors.success : AppColors.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      printerState.isConnected ? Icons.print : Icons.print_disabled,
                      color: printerState.isConnected ? AppColors.success : AppColors.textSecondary,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            printerState.isConnected ? 'Printer Terhubung' : 'Printer Belum Terhubung',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: printerState.isConnected ? AppColors.success : AppColors.textPrimary,
                            ),
                          ),
                          if (printerState.connectedMac != null)
                            Text(
                              'MAC: ${printerState.connectedMac}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    if (printerState.isConnected)
                      TextButton(
                        onPressed: () => ref.read(printerProvider.notifier).disconnect(),
                        child: const Text('Putuskan', style: TextStyle(color: AppColors.danger)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card: Menu Pairing & Bantuan Bluetooth HP
            Card(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.primary),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bluetooth_searching, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Menu Pairing & Izin Bluetooth',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Jika printer Anda belum muncul di daftar bawah atau gagal terkoneksi, silakan buka menu pairing Android atau pastikan izin Bluetooth aplikasi sudah aktif.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.settings_bluetooth, size: 18),
                            label: const Text('Buka Pairing HP', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              await ref.read(printerProvider.notifier).openNativeBluetoothSettings();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.security, size: 18),
                            label: const Text('Cek Izin BT', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final granted = await ref.read(printerProvider.notifier).requestPermission();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(granted ? 'Izin Bluetooth telah aktif!' : 'Izin Bluetooth belum diberikan.'),
                                    backgroundColor: granted ? AppColors.success : AppColors.warning,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Card: Input Alamat MAC Langsung
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hubungkan Langsung via Alamat MAC',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ketik atau tempel alamat MAC Bluetooth printer Anda (biasanya tercetak di label stiker bawah printer).',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _macController,
                            decoration: const InputDecoration(
                              hintText: 'Misal: 66:02:BD:06:18:7B',
                              prefixIcon: Icon(Icons.qr_code, size: 20),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _isConnectingManual ? null : _connectManual,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: _isConnectingManual
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Konek'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Paper Size Setting
            const Text('Ukuran Kertas Thermal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('58 mm (Standar)')),
                    selected: printerState.paperSize == PaperSize.mm58,
                    selectedColor: AppColors.primaryContainer,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(printerProvider.notifier).setPaperSize(PaperSize.mm58);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('80 mm (Besar)')),
                    selected: printerState.paperSize == PaperSize.mm80,
                    selectedColor: AppColors.primaryContainer,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(printerProvider.notifier).setPaperSize(PaperSize.mm80);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Test Print Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text('Tes Cetak Struk'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  final freshStore = await ref.read(settingsRepositoryProvider).getStore();
                  final success = await ref.read(printerProvider.notifier).testPrint(freshStore);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Tes cetak berhasil dikirim ke printer!' : 'Gagal mengirim data ke printer. Pastikan printer menyala & terhubung.'),
                        backgroundColor: success ? AppColors.success : AppColors.danger,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Bluetooth devices list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Perangkat Bluetooth Paired Terdeteksi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                if (printerState.isScanning)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),

            if (printerState.availableDevices.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.bluetooth_searching, size: 36, color: AppColors.textMuted),
                    SizedBox(height: 8),
                    Text(
                      'Belum ada perangkat Bluetooth terdeteksi.\n1. Pastikan Bluetooth HP sudah aktif.\n2. Klik "Cek Izin BT" di atas untuk mengizinkan akses.\n3. Atau ketik alamat MAC printer langsung pada kolom di atas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: printerState.availableDevices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final dev = printerState.availableDevices[index];
                  final isThisConnected = printerState.connectedMac == dev.macAdress;

                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(Icons.bluetooth, color: isThisConnected ? AppColors.primary : AppColors.textSecondary),
                      title: Text(dev.name.isNotEmpty ? dev.name : 'Printer Thermal', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(dev.macAdress),
                      trailing: isThisConnected
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.successContainer, borderRadius: BorderRadius.circular(6)),
                              child: const Text('TERHUBUNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                              onPressed: () async {
                                final ok = await ref.read(printerProvider.notifier).connect(dev.macAdress);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'Berhasil terhubung ke ${dev.name}' : 'Gagal menghubungkan printer'),
                                      backgroundColor: ok ? AppColors.success : AppColors.danger,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Hubungkan', style: TextStyle(fontSize: 12)),
                            ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Tombol Kembali ke Dashboard (Issue #1)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.dashboard_outlined, color: Colors.white, size: 20),
                label: const Text(
                  'Kembali ke Dashboard',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                onPressed: () => _returnToDashboard(context),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }
}
