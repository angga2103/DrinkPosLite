import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../security/audit_logger.dart';
import '../utils/date_formatter.dart';

class BackupResult {
  final bool success;
  final String? filePath;
  final String? fileName;
  final int fileSizeBytes;
  final String? errorMessage;

  BackupResult({
    required this.success,
    this.filePath,
    this.fileName,
    this.fileSizeBytes = 0,
    this.errorMessage,
  });
}

class BackupService {
  static Future<BackupResult> createBackup({String backupType = 'MANUAL', String? userId}) async {
    try {
      final dbPath = await AppDatabase.instance.getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return BackupResult(success: false, errorMessage: 'File database utama tidak ditemukan');
      }

      // Checkpoint WAL to flush all transactions to the main DB file
      final db = await AppDatabase.instance.database;
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(FULL);');
      } catch (_) {}

      // Get backup target directory (e.g. app documents / backups folder)
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(docsDir.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final fileName = 'DrinkPOS_Backup_${DateFormatter.forFileName(DateTime.now())}.db';
      final backupFilePath = p.join(backupDir.path, fileName);

      // Copy database file
      final backupFile = await dbFile.copy(backupFilePath);
      final fileSize = await backupFile.length();

      // Log in audit log
      await AuditLogger.log(
        action: 'BACKUP_CREATE',
        entityType: 'DATABASE',
        entityId: fileName,
        userId: userId,
        reason: 'Backup $backupType berhasil dibuat ($fileSize bytes)',
      );

      // Record in backup history
      await db.insert('backup_history', {
        'id': 'bak_${DateTime.now().millisecondsSinceEpoch}',
        'backup_date': DateTime.now().toIso8601String(),
        'file_name': fileName,
        'file_size_bytes': fileSize,
        'file_path': backupFilePath,
        'backup_type': backupType,
        'status': 'SUCCESS',
      });

      return BackupResult(
        success: true,
        filePath: backupFilePath,
        fileName: fileName,
        fileSizeBytes: fileSize,
      );
    } catch (e) {
      return BackupResult(success: false, errorMessage: 'Gagal membuat backup: $e');
    }
  }

  static Future<void> shareBackupFile(String filePath, String fileName) async {
    await Share.shareXFiles(
      [XFile(filePath, name: fileName)],
      text: 'File Backup Database DrinkPOS Lite ($fileName)',
      subject: 'Backup Database DrinkPOS Lite',
    );
  }

  static Future<bool> validateBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;
      if (await file.length() < 100) return false;

      // Verify SQLite header string
      final bytes = await file.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes);
      if (!header.startsWith('SQLite format 3')) {
        return false;
      }

      // Try opening read-only and running integrity check
      final testDb = await openReadOnlyDatabase(filePath);
      final checkRes = await testDb.rawQuery('PRAGMA integrity_check;');
      await testDb.close();

      if (checkRes.isEmpty || checkRes.first['integrity_check'] != 'ok') {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<BackupResult> restoreFromBackup({
    required String backupFilePath,
    required String ownerUserId,
  }) async {
    File? safetyBackupFile;
    try {
      // 1. Validate incoming file
      final isValid = await validateBackupFile(backupFilePath);
      if (!isValid) {
        return BackupResult(
          success: false,
          errorMessage: 'File bukan database SQLite DrinkPOS Lite yang valid atau rusak.',
        );
      }

      final incomingFile = File(backupFilePath);
      final currentDbPath = await AppDatabase.instance.getDatabasePath();
      final currentDbFile = File(currentDbPath);

      // 2. Make safety backup of current database
      if (await currentDbFile.exists()) {
        final tempDir = await getTemporaryDirectory();
        final safetyPath = p.join(tempDir.path, 'current_safety_backup.db');
        safetyBackupFile = await currentDbFile.copy(safetyPath);
      }

      // 3. Close active database connection
      await AppDatabase.instance.close();

      // 4. Overwrite main DB with backup
      await incomingFile.copy(currentDbPath);

      // Also remove any existing WAL/SHM files
      final walFile = File('$currentDbPath-wal');
      if (await walFile.exists()) await walFile.delete();
      final shmFile = File('$currentDbPath-shm');
      if (await shmFile.exists()) await shmFile.delete();

      // 5. Verify the restored database opens and runs
      final restoredDb = await AppDatabase.instance.database;
      final integrity = await restoredDb.rawQuery('PRAGMA integrity_check;');
      if (integrity.isEmpty || integrity.first['integrity_check'] != 'ok') {
        throw Exception('Integritas database hasil restore tidak valid');
      }

      // 6. Log audit
      await AuditLogger.log(
        action: 'RESTORE_DATABASE',
        entityType: 'DATABASE',
        entityId: p.basename(backupFilePath),
        userId: ownerUserId,
        reason: 'Restore database berhasil dari ${p.basename(backupFilePath)}',
        db: restoredDb,
      );

      // Clean up safety backup
      if (safetyBackupFile != null && await safetyBackupFile.exists()) {
        await safetyBackupFile.delete();
      }

      return BackupResult(
        success: true,
        fileName: p.basename(backupFilePath),
        fileSizeBytes: await incomingFile.length(),
      );
    } catch (e) {
      // Rollback to safety backup if something failed!
      if (safetyBackupFile != null && await safetyBackupFile.exists()) {
        try {
          await AppDatabase.instance.close();
          final currentDbPath = await AppDatabase.instance.getDatabasePath();
          await safetyBackupFile.copy(currentDbPath);
          await AppDatabase.instance.database; // Re-open
        } catch (_) {}
      }

      return BackupResult(
        success: false,
        errorMessage: 'Gagal memulihkan database: $e. Database saat ini telah dipulihkan ke kondisi semula.',
      );
    }
  }
}
