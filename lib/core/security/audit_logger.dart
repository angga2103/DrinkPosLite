import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../utils/id_generator.dart';

class AuditLogger {
  static Future<void> log({
    required String action,
    required String entityType,
    String? entityId,
    String? userId,
    String? userName,
    String? oldValue,
    String? newValue,
    String? reason,
    DatabaseExecutor? db,
  }) async {
    try {
      final database = db ?? await AppDatabase.instance.database;
      await database.insert('audit_logs', {
        'id': IdGenerator.generateId(prefix: 'aud'),
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'user_id': userId,
        'user_name': userName ?? 'User',
        'old_value': oldValue,
        'new_value': newValue,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Safe fallback
    }
  }
}
