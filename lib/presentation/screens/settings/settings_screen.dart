import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/sync_package_service.dart';
import '../../../data/models/store_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../backup/backup_screen.dart';
import 'about_screen.dart';
import 'audit_log_screen.dart';
import 'printer_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _headerController;
  late TextEditingController _footerController;
  String? _logoPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final store = ref.read(settingsProvider).store;
    _nameController = TextEditingController(text: store.name);
    _addressController = TextEditingController(text: store.address);
    _phoneController = TextEditingController(text: store.phone);
    _headerController = TextEditingController(text: store.receiptHeader);
    _footerController = TextEditingController(text: store.receiptFooter);
    _logoPath = store.logoPath;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(settingsProvider.notifier).loadSettings();
      if (mounted) {
        final fresh = ref.read(settingsProvider).store;
        _nameController.text = fresh.name;
        _addressController.text = fresh.address;
        _phoneController.text = fresh.phone;
        _headerController.text = fresh.receiptHeader;
        _footerController.text = fresh.receiptFooter;
        setState(() {
          _logoPath = fresh.logoPath;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final user = ref.read(authProvider).currentUser;
    final canEdit = (user?.isOwner ?? false) || (user?.isManager ?? false);
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya Pemilik (Owner) dan Manajer yang berhak mengubah logo toko!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    try {
      final pickedFile = await FilePicker.pickFile(type: FileType.image);
      if (pickedFile != null && pickedFile.path != null) {
        final pickedPath = pickedFile.path!;
        final appDir = await getApplicationDocumentsDirectory();
        final ext = pickedPath.split('.').last;
        final targetFile = File('${appDir.path}/store_logo_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await File(pickedPath).copy(targetFile.path);

        setState(() {
          _logoPath = targetFile.path;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logo berhasil dipilih. Tekan "Simpan Pengaturan Toko" untuk menerapkan.'),
              backgroundColor: AppColors.info,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _removeLogo() {
    final user = ref.read(authProvider).currentUser;
    final canEdit = (user?.isOwner ?? false) || (user?.isManager ?? false);
    if (!canEdit) return;

    setState(() {
      _logoPath = null;
    });
  }

  Future<void> _saveStore() async {
    final user = ref.read(authProvider).currentUser;
    final canEdit = (user?.isOwner ?? false) || (user?.isManager ?? false);
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akses ditolak: Hanya Pemilik (Owner) dan Manajer yang dapat menyimpan profil toko!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final currentStore = ref.read(settingsProvider).store;

    final updated = StoreModel(
      id: currentStore.id,
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      receiptHeader: _headerController.text.trim(),
      receiptFooter: _footerController.text.trim(),
      logoPath: _logoPath,
    );

    try {
      await ref.read(settingsProvider.notifier).updateStore(updated, userId: user?.id);

      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan toko dan logo berhasil disimpan!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan identitas toko: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _shareSyncPackage() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await SyncPackageService.sharePackageToWhatsApp();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat paket update: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _importSyncPackage() async {
    try {
      final pickedFile = await FilePicker.pickFile(type: FileType.any);
      if (pickedFile == null || pickedFile.path == null) return;
      final filePath = pickedFile.path!;
      final user = ref.read(authProvider).currentUser;
      if (!mounted) return;
      await SyncPackageService.handleIncomingPackageFile(
        context,
        filePath,
        appliedByUserId: user?.id,
        onApplied: () => ref.read(settingsProvider.notifier).loadSettings(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menerapkan paket: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final user = ref.watch(authProvider).currentUser;
    final canEditStore = (user?.isOwner ?? false) || (user?.isManager ?? false);

    return AppScaffold(
      title: 'Pengaturan Toko',
      currentRoute: '/settings',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Identitas Kedai / Toko',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: canEditStore ? AppColors.successContainer : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              canEditStore ? 'BISA DIUBAH' : 'HANYA BACA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: canEditStore ? AppColors.success : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!canEditStore) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Hanya Pemilik (Owner) dan Manajer yang berhak mengubah identitas toko & logo.',
                          style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        enabled: canEditStore,
                        decoration: const InputDecoration(labelText: 'Nama Toko / Kedai Minuman'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Nama toko wajib diisi' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _addressController,
                        enabled: canEditStore,
                        decoration: const InputDecoration(labelText: 'Alamat Toko'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneController,
                        enabled: canEditStore,
                        decoration: const InputDecoration(labelText: 'Nomor Telepon Toko'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _headerController,
                        enabled: canEditStore,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Header Struk Pembayaran'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _footerController,
                        enabled: canEditStore,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Pesan Footer Struk (Ucapan Terima Kasih)'),
                      ),
                      const SizedBox(height: 16),

                      // Store Logo Section
                      const Text('Logo Struk Thermal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text(
                        'Logo otomatis dikonversi ke hitam-putih (1-bit monochrome raster) agar tercetak jernih di struk printer thermal.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      if (_logoPath != null && File(_logoPath!).existsSync()) ...[
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.cardBorder),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(_logoPath!), fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (canEditStore)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.photo, size: 16),
                                      label: const Text('Ganti Logo'),
                                      onPressed: _pickLogo,
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                      label: const Text('Hapus Logo', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                                      onPressed: _removeLogo,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ] else ...[
                        if (canEditStore)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Pilih Gambar Logo Toko'),
                            onPressed: _pickLogo,
                          )
                        else
                          const Text('Belum ada logo toko yang diatur.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                      const SizedBox(height: 16),

                      if (canEditStore)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveStore,
                            child: const Text('Simpan Pengaturan Toko'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Remote Update Sync Card (WhatsApp Sync)
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.sync_alt, color: Color(0xFF128C7E), size: 22),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pembaruan Jarak Jauh (WhatsApp Sync)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF128C7E)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Kirim atau terapkan berkas pembaruan resep racikan, menu, dan stok bahan baku (.dpos) via WhatsApp tanpa pinjam HP kasir dan tanpa internet.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    if (user?.isOwner ?? false) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.send, size: 18),
                          label: const Text(
                            'Kirim Paket Update ke WhatsApp Kasir (Owner)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: _shareSyncPackage,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF128C7E),
                          side: const BorderSide(color: Color(0xFF128C7E)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.file_download_outlined, size: 18),
                        label: const Text(
                          'Impor Paket Update dari WhatsApp (.dpos)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _importSyncPackage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Security & Auto-Lock Setting
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Keamanan & Kunci Otomatis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Aplikasi akan terkunci otomatis jika tidak ada sentuhan layar selama durasi ini:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [1, 5, 10, 15].map((mins) {
                        final isSelected = settingsState.autoLockMinutes == mins;
                        return ChoiceChip(
                          label: Text('$mins Menit'),
                          selected: isSelected,
                          selectedColor: AppColors.primaryContainer,
                          onSelected: (selected) {
                            if (selected) {
                              ref.read(settingsProvider.notifier).updateAutoLock(mins);
                              ref.read(authProvider.notifier).setAutoLockMinutes(mins);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Menu Links
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.print_outlined, color: AppColors.primary),
                    title: const Text('Pengaturan Printer Thermal'),
                    subtitle: const Text('Koneksi Bluetooth, pairing aplikasi & ukuran kertas 58mm/80mm'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined, color: AppColors.primary),
                    title: const Text('Backup & Restore Database'),
                    subtitle: const Text('Cadangkan data dan pulihkan database offline'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BackupScreen()),
                      );
                    },
                  ),
                  if (user?.isOwner ?? false) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.security, color: AppColors.primary),
                      title: const Text('Audit Log Keamanan'),
                      subtitle: const Text('Catatan perubahan harga, resep, PIN & pembatalan'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                        );
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: AppColors.primary),
                    title: const Text('Tentang Aplikasi & Developer'),
                    subtitle: const Text('Informasi versi, lisensi & kontak developer'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mandatory Developer Identity Banner with WhatsApp Direct Link
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  const Text(
                    AppConstants.developedByText,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => DeviceService.openWhatsApp(
                      phone: AppConstants.developerContact,
                      message: 'Halo Ansor.Studio, saya pengguna aplikasi DrinkPOS Lite.',
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.chat, size: 16, color: Color(0xFF128C7E)),
                          SizedBox(width: 6),
                          Text(
                            AppConstants.contactText,
                            style: TextStyle(fontSize: 13, color: Color(0xFF128C7E), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Klik nomor di atas untuk menghubungi via WhatsApp',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
