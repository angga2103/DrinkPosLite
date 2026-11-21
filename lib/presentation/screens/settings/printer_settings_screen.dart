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

  Future<void> _setManualMac({required bool forKitchen}) async {
    final mac = _macController.text.trim();
    if (mac.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan alamat MAC printer (contoh: 66:02:BD:06:18:7B)')),
      );
      return;
    }

    setState(() => _isConnectingManual = true);
    if (forKitchen) {
      await ref.read(printerProvider.notifier).setKitchenPrinter(mac, name: 'Printer Dapur ($mac)');
      await ref.read(printerProvider.notifier).setKitchenEnabled(true);
    } else {
      await ref.read(printerProvider.notifier).setCashierPrinter(mac, name: 'Printer Kasir ($mac)');
    }
    final ok = await ref.read(printerProvider.notifier).connect(mac);
    setState(() => _isConnectingManual = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Berhasil menyimpan & menghubungkan ${forKitchen ? "Printer Dapur" : "Printer Kasir"}!'
              : 'Alamat MAC disimpan, tetapi printer belum terhubung. Pastikan printer menyala & Bluetooth aktif.'),
          backgroundColor: ok ? AppColors.success : AppColors.warning,
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
          title: const Text('Pengaturan Dual Printer Thermal'),
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
              // 1. KARTU PRINTER KASIR
              _buildPrinterSectionCard(
                title: '1. Printer Kasir (Struk Konsumen)',
                icon: Icons.point_of_sale,
                iconColor: AppColors.primary,
                assignedName: printerState.cashierName,
                assignedMac: printerState.cashierMac,
                isAssignedConnected: printerState.isConnected && printerState.connectedMac == printerState.cashierMac,
                onTestPrint: () async {
                  final freshStore = await ref.read(settingsRepositoryProvider).getStore();
                  final success = await ref.read(printerProvider.notifier).testPrint(freshStore, forKitchen: false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Tes cetak kasir berhasil dikirim!' : 'Gagal mengirim data ke printer kasir.'),
                        backgroundColor: success ? AppColors.success : AppColors.danger,
                      ),
                    );
                  }
                },
                testButtonLabel: 'Tes Cetak Struk Kasir',
              ),
              const SizedBox(height: 16),

              // 2. KARTU PRINTER DAPUR / BARISTA
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: printerState.isKitchenEnabled ? AppColors.secondary : AppColors.cardBorder,
                    width: printerState.isKitchenEnabled ? 1.5 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.coffee, color: printerState.isKitchenEnabled ? AppColors.secondary : AppColors.textSecondary, size: 24),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '2. Printer Dapur / Barista (Tiket Pesanan)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aktifkan Printer Dapur Terpisah', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                          'Cetak tiket pesanan khusus menu racikan langsung di printer bagian dapur',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        value: printerState.isKitchenEnabled,
                        activeColor: AppColors.secondary,
                        onChanged: (val) {
                          ref.read(printerProvider.notifier).setKitchenEnabled(val);
                        },
                      ),
                      if (printerState.isKitchenEnabled) ...[
                        const Divider(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Cetak Otomatis ke Dapur Saat Bayar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text(
                            'Setelah kasir klik bayar, tiket dapur langsung tercetak otomatis tanpa perlu tombol reprint',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          value: printerState.autoPrintKitchen,
                          activeColor: AppColors.secondary,
                          onChanged: (val) {
                            ref.read(printerProvider.notifier).setAutoPrintKitchen(val);
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (printerState.isConnected && printerState.connectedMac == printerState.kitchenMac)
                                    ? Icons.check_circle
                                    : Icons.info_outline,
                                color: (printerState.isConnected && printerState.connectedMac == printerState.kitchenMac)
                                    ? AppColors.success
                                    : AppColors.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      printerState.kitchenName ?? 'Printer Dapur Belum Dipilih',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      printerState.kitchenMac != null
                                          ? 'MAC: ${printerState.kitchenMac}'
                                          : 'Pilih salah satu printer di daftar Bluetooth bawah dengan tombol [Set Dapur]',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.receipt),
                            label: const Text('Tes Cetak Tiket Dapur'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              final freshStore = await ref.read(settingsRepositoryProvider).getStore();
                              final success = await ref.read(printerProvider.notifier).testPrint(freshStore, forKitchen: true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success ? 'Tes tiket dapur berhasil dikirim!' : 'Gagal mengirim data ke printer dapur.'),
                                    backgroundColor: success ? AppColors.success : AppColors.danger,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
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
                        'Jika printer belum muncul di daftar bawah, lakukan pairing Bluetooth terlebih dahulu melalui pengaturan Android HP Anda.',
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
                      TextField(
                        controller: _macController,
                        decoration: const InputDecoration(
                          hintText: 'Misal: 66:02:BD:06:18:7B',
                          prefixIcon: Icon(Icons.qr_code, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.point_of_sale, size: 16),
                              label: const Text('Set Kasir', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                              onPressed: _isConnectingManual ? null : () => _setManualMac(forKitchen: false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.coffee, size: 16),
                              label: const Text('Set Dapur', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                              onPressed: _isConnectingManual ? null : () => _setManualMac(forKitchen: true),
                            ),
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
              const SizedBox(height: 24),

              // Bluetooth devices list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daftar Perangkat Bluetooth HP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                        'Belum ada perangkat Bluetooth terdeteksi.\n1. Pastikan Bluetooth HP sudah aktif.\n2. Klik "Buka Pairing HP" di atas untuk menghubungkan printer terlebih dahulu.\n3. Atau ketik alamat MAC printer langsung pada kolom di atas.',
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
                    final isCashier = printerState.cashierMac == dev.macAdress;
                    final isKitchen = printerState.kitchenMac == dev.macAdress;
                    final isConnected = printerState.connectedMac == dev.macAdress && printerState.isConnected;

                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.print, color: isConnected ? AppColors.success : AppColors.textSecondary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dev.name.isNotEmpty ? dev.name : 'Printer Thermal',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(dev.macAdress, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                if (isConnected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.successContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('TERKONEKSI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (isCashier)
                                  Chip(
                                    label: const Text('Printer Kasir Aktif', style: TextStyle(fontSize: 11, color: Colors.white)),
                                    backgroundColor: AppColors.primary,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                if (isKitchen)
                                  Chip(
                                    label: const Text('Printer Dapur Aktif', style: TextStyle(fontSize: 11, color: Colors.white)),
                                    backgroundColor: AppColors.secondary,
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    onPressed: () async {
                                      await ref.read(printerProvider.notifier).setCashierPrinter(dev.macAdress, name: dev.name);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('${dev.name} diset sebagai Printer Kasir'), backgroundColor: AppColors.primary),
                                        );
                                      }
                                    },
                                    child: const Text('Set sbg Kasir', style: TextStyle(fontSize: 11)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.secondary,
                                      side: const BorderSide(color: AppColors.secondary),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    onPressed: () async {
                                      await ref.read(printerProvider.notifier).setKitchenPrinter(dev.macAdress, name: dev.name);
                                      await ref.read(printerProvider.notifier).setKitchenEnabled(true);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('${dev.name} diset sebagai Printer Dapur'), backgroundColor: AppColors.secondary),
                                        );
                                      }
                                    },
                                    child: const Text('Set sbg Dapur', style: TextStyle(fontSize: 11)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
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
                                  child: const Text('Konek', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              // Tombol Kembali ke Dashboard
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

  Widget _buildPrinterSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String? assignedName,
    required String? assignedMac,
    required bool isAssignedConnected,
    required VoidCallback onTestPrint,
    required String testButtonLabel,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isAssignedConnected ? AppColors.success : AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isAssignedConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.successContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('TERKONEKSI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    isAssignedConnected ? Icons.check_circle : Icons.print_disabled,
                    color: isAssignedConnected ? AppColors.success : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignedName ?? 'Belum Dipilih',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          assignedMac != null
                              ? 'MAC: $assignedMac'
                              : 'Pilih printer dari daftar perangkat Bluetooth di bawah',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: Text(testButtonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: onTestPrint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
