import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/date_formatter.dart';

class AttendancePhotoService {
  static final ImagePicker _picker = ImagePicker();

  /// 1. Ambil foto selfie menggunakan kamera depan perangkat
  static Future<File?> captureSelfie() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 960,
        maxHeight: 960,
      );
      if (photo == null) return null;
      return File(photo.path);
    } catch (_) {
      return null;
    }
  }

  /// 2. Bubuhkan Watermark Otomatis & Anti-Manipulasi Permanen pada Piksel Foto
  static Future<File> applyWatermark({
    required File originalFile,
    required String storeName,
    required String employeeName,
    required String actionType, // 'CLOCK-IN' atau 'CLOCK-OUT'
    required String status,
    required int latenessMinutes,
    String? shiftSchedule,
  }) async {
    final bytes = await originalFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return originalFile;

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} WIB';
    final dateStr = DateFormatter.formatDateFull(now);

    // Ketinggian watermark bar di bagian bawah foto
    final bannerHeight = 110;
    final startY = image.height - bannerHeight > 0 ? image.height - bannerHeight : 0;

    // Gambar background banner gelap transparan
    img.fillRect(
      image,
      x1: 0,
      y1: startY,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(10, 25, 20, 215), // Dark teal overlay
    );

    // Garis aksen atas banner
    img.fillRect(
      image,
      x1: 0,
      y1: startY,
      x2: image.width,
      y2: startY + 3,
      color: img.ColorRgba8(0, 200, 150, 255), // Teal accent line
    );

    // Watermark Text:
    // Baris 1: Identitas Toko & Aplikasi
    img.drawString(
      image,
      'DRINKPOS LITE - VERIFIED ATTENDANCE',
      font: img.arial14,
      x: 16,
      y: startY + 10,
      color: img.ColorRgba8(0, 230, 180, 255),
    );

    // Baris 2: Toko & Pegawai
    img.drawString(
      image,
      '$storeName | Pegawai: $employeeName ($actionType)',
      font: img.arial14,
      x: 16,
      y: startY + 32,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    // Baris 3: Tanggal & Waktu Riil
    img.drawString(
      image,
      'Waktu: $dateStr, $timeStr',
      font: img.arial14,
      x: 16,
      y: startY + 54,
      color: img.ColorRgba8(255, 240, 180, 255),
    );

    // Baris 4: Status Keterlambatan / Jadwal
    final statusDetail = latenessMinutes > 0
        ? 'STATUS: TERLAMBAT $latenessMinutes MENIT'
        : 'STATUS: $status (TEPAT WAKTU)';
    final scheduleText = shiftSchedule != null ? ' | Jadwal: $shiftSchedule' : '';

    img.drawString(
      image,
      '$statusDetail$scheduleText',
      font: img.arial14,
      x: 16,
      y: startY + 76,
      color: latenessMinutes > 0
          ? img.ColorRgba8(255, 100, 100, 255)
          : img.ColorRgba8(120, 255, 150, 255),
    );

    // Kompresi JPEG hemat penyimpanan (~100-150 KB)
    final watermarkedBytes = img.encodeJpg(image, quality: 80);

    // Simpan ke direktori dokumen permanen
    final docsDir = await getApplicationDocumentsDirectory();
    final selfiesDir = Directory(p.join(docsDir.path, 'attendance_selfies'));
    if (!await selfiesDir.exists()) {
      await selfiesDir.create(recursive: true);
    }

    final safeEmployee = employeeName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'Selfie_${actionType}_${safeEmployee}_${now.millisecondsSinceEpoch}.jpg';
    final savedFile = File(p.join(selfiesDir.path, fileName));
    await savedFile.writeAsBytes(watermarkedBytes, flush: true);

    return savedFile;
  }

  /// 3. Format & Kirim Bukti Absensi Langsung ke WhatsApp Owner
  static Future<void> shareAttendanceToWhatsApp({
    required File photoFile,
    required String storeName,
    required String employeeName,
    required String actionType, // 'CLOCK-IN' atau 'CLOCK-OUT'
    required String status,
    required int latenessMinutes,
    required String clockTime,
    String? shiftSchedule,
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormatter.formatDateFull(now);

    final buffer = StringBuffer();
    buffer.writeln('📸 *BUKTI ABSENSI ${actionType == "CLOCK-IN" ? "MASUK" : "PULANG"} — DRINKPOS LITE*');
    buffer.writeln('🏪 *Kedai:* $storeName');
    buffer.writeln('-----------------------------------');
    buffer.writeln('👤 *Pegawai:* $employeeName');
    buffer.writeln('📅 *Hari/Tanggal:* $dateStr');
    buffer.writeln('⏰ *Waktu $actionType:* $clockTime WIB');
    if (shiftSchedule != null && shiftSchedule.isNotEmpty) {
      buffer.writeln('⏱️ *Jadwal Shift:* $shiftSchedule');
    }

    if (latenessMinutes > 0) {
      buffer.writeln('⚠️ *Status:* TERLAMBAT ($latenessMinutes Menit)');
    } else {
      buffer.writeln('✅ *Status:* $status (Tepat Waktu)');
    }

    buffer.writeln('-----------------------------------');
    buffer.writeln('🔒 _Foto selfie ter-watermark otomatis terlampir langsung dari aplikasi DrinkPOS Lite._');

    await Share.shareXFiles(
      [XFile(photoFile.path, mimeType: 'image/jpeg', name: p.basename(photoFile.path))],
      text: buffer.toString(),
      subject: 'Bukti Absensi $employeeName ($actionType)',
    );
  }
}
