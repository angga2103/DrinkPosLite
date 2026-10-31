import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/device_service.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang Aplikasi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App Logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_cafe, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              AppConstants.appName,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const Text(
              'Versi 1.0.0 (Build 1)',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '100% Offline-First • Standalone Local POS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ),
            const SizedBox(height: 24),

            // Developer Info Card (MANDATORY PROMPT REQUIREMENT)
            Card(
              color: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'INFORMASI PENGEMBANG',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      AppConstants.developedByText,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => DeviceService.openWhatsApp(
                        phone: AppConstants.developerContact,
                        message: 'Halo Ansor.Studio, saya pengguna aplikasi DrinkPOS Lite.',
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.chat, color: Color(0xFF128C7E), size: 16),
                            SizedBox(width: 6),
                            Text(
                              AppConstants.contactText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF128C7E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tekan nomor untuk chat WhatsApp pengembang',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Target Users & Features
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Pengguna:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Kedai es teh & teh kekinian\n'
                      '• Kedai kopi & coffee shop UMKM\n'
                      '• Kedai cokelat, susu, & boba\n'
                      '• Kedai jus buah segar\n'
                      '• Usaha minuman franchise & gerobakan',
                      style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Karakteristik Aplikasi:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '✓ 100% Beroperasi Offline Tanpa Internet\n'
                      '✓ Database SQLite Lokal di Perangkat\n'
                      '✓ Transaksi Atomik & Aman\n'
                      '✓ Cetak Struk Bluetooth ESC/POS\n'
                      '✓ Laporan PDF, Excel XLSX, & WhatsApp\n'
                      '✓ Ekspor-Impor Resep & Stok Aman via WA',
                      style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
