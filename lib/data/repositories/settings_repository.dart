import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/utils/id_generator.dart';
import '../models/audit_model.dart';
import '../models/store_model.dart';

class SettingsRepository {
  final AppDatabase _appDb;
  SettingsRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<StoreModel> getStore() async {
    final db = await _appDb.database;
    final res = await db.query('stores', limit: 1);
    if (res.isEmpty) {
      // Fallback from SharedPreferences if available
      try {
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString('store_name');
        if (name != null && name.isNotEmpty) {
          return StoreModel(
            id: prefs.getString('store_id') ?? 'store_main',
            name: name,
            address: prefs.getString('store_address') ?? '',
            phone: prefs.getString('store_phone') ?? '081775700114',
            receiptHeader: prefs.getString('store_receipt_header') ?? 'DRINKPOS LITE',
            receiptFooter: prefs.getString('store_receipt_footer') ?? 'Terima Kasih!',
            logoPath: prefs.getString('store_logo_path'),
          );
        }
      } catch (_) {}

      return StoreModel(
        id: 'store_main',
        name: 'Kedai Minuman',
        address: '',
        phone: '081775700114',
        receiptHeader: 'DRINKPOS LITE',
        receiptFooter: 'Terima Kasih!',
      );
    }

    var store = StoreModel.fromMap(res.first);

    // Complement logo path from SharedPreferences if SQLite was null
    if (store.logoPath == null || store.logoPath!.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedLogo = prefs.getString('store_logo_path');
        if (cachedLogo != null && File(cachedLogo).existsSync()) {
          store = StoreModel(
            id: store.id,
            name: store.name,
            address: store.address,
            phone: store.phone,
            receiptHeader: store.receiptHeader,
            receiptFooter: store.receiptFooter,
            currency: store.currency,
            logoPath: cachedLogo,
          );
        }
      } catch (_) {}
    }

    return store;
  }

  Future<void> updateStore(StoreModel store, {String? operatorUserId}) async {
    final db = await _appDb.database;
    final now = DateTime.now().toIso8601String();

    // Check if store already exists
    final existing = await db.query('stores', limit: 1);
    if (existing.isEmpty) {
      await db.insert(
        'stores',
        {
          ...store.toMap(),
          'created_at': now,
          'updated_at': now,
        },
      );
    } else {
      final existingId = existing.first['id'] as String? ?? store.id;
      await db.update(
        'stores',
        {
          'name': store.name,
          'address': store.address,
          'phone': store.phone,
          'receipt_header': store.receiptHeader,
          'receipt_footer': store.receiptFooter,
          'currency': store.currency,
          'logo_path': store.logoPath,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
    }

    // Backup to SharedPreferences for instant cross-session persistence
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('store_id', store.id);
      await prefs.setString('store_name', store.name);
      await prefs.setString('store_address', store.address);
      await prefs.setString('store_phone', store.phone);
      await prefs.setString('store_receipt_header', store.receiptHeader);
      await prefs.setString('store_receipt_footer', store.receiptFooter);
      if (store.logoPath != null && store.logoPath!.isNotEmpty) {
        await prefs.setString('store_logo_path', store.logoPath!);
      } else {
        await prefs.remove('store_logo_path');
      }
    } catch (_) {}

    await AuditLogger.log(
      action: 'STORE_UPDATE',
      entityType: 'STORE',
      entityId: store.id,
      userId: operatorUserId,
      reason: 'Pembaruan informasi toko: ${store.name}',
      db: db,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await _appDb.database;
    final res = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (res.isEmpty) return null;
    return res.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _appDb.database;
    await db.insert(
      'app_settings',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AuditLogModel>> getAuditLogs({int limit = 100}) async {
    final db = await _appDb.database;
    final res = await db.query('audit_logs', orderBy: 'created_at DESC', limit: limit);
    return res.map((m) => AuditLogModel.fromMap(m)).toList();
  }

  Future<void> recordBackup({
    required String fileName,
    required int fileSizeBytes,
    required String filePath,
    String backupType = 'MANUAL',
    String status = 'SUCCESS',
    String? errorMessage,
  }) async {
    final db = await _appDb.database;
    await db.insert('backup_history', {
      'id': IdGenerator.generateId(prefix: 'bak'),
      'backup_date': DateTime.now().toIso8601String(),
      'file_name': fileName,
      'file_size_bytes': fileSizeBytes,
      'file_path': filePath,
      'backup_type': backupType,
      'status': status,
      'error_message': errorMessage,
    });
  }

  Future<List<Map<String, dynamic>>> getBackupHistory({int limit = 30}) async {
    final db = await _appDb.database;
    return await db.query('backup_history', orderBy: 'backup_date DESC', limit: limit);
  }
}
