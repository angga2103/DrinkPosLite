import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/security/pin_security.dart';
import '../models/user_model.dart';

class EmployeeRepository {
  final AppDatabase _appDb;
  EmployeeRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<List<UserModel>> getEmployees({bool activeOnly = false}) async {
    final db = await _appDb.database;
    final where = activeOnly ? 'is_active = 1' : null;
    final res = await db.query(
      'users',
      where: where,
      orderBy: "CASE role WHEN 'OWNER' THEN 1 WHEN 'MANAGER' THEN 2 ELSE 3 END, name ASC",
    );
    return res.map((m) => UserModel.fromMap(m)).toList();
  }

  Future<void> saveEmployee({
    required UserModel employee,
    String? newRawPin,
    String? operatorUserId,
  }) async {
    final db = await _appDb.database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query('users', where: 'id = ?', whereArgs: [employee.id]);

    final map = employee.toMap();
    if (newRawPin != null && newRawPin.isNotEmpty) {
      map['pin_hash'] = PinSecurity.hashPin(newRawPin);
      map['failed_attempts'] = 0;
      map['is_locked'] = 0;
    }

    if (existing.isEmpty) {
      map['created_at'] = now;
      map['updated_at'] = now;
      await db.insert('users', map);
    } else {
      map['updated_at'] = now;
      await db.update('users', map, where: 'id = ?', whereArgs: [employee.id]);
    }

    await AuditLogger.log(
      action: existing.isEmpty ? 'EMPLOYEE_CREATE' : 'EMPLOYEE_UPDATE',
      entityType: 'USER',
      entityId: employee.id,
      userId: operatorUserId,
      reason: 'Simpan pegawai ${employee.name} (${employee.role})',
      db: db,
    );
  }

  Future<bool> deleteEmployee(String userId, [String? operatorUserId]) async {
    try {
      final db = await _appDb.database;
      final userRes = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      final userName = userRes.isNotEmpty ? userRes.first['name'] : userId;
      await db.delete('users', where: 'id = ?', whereArgs: [userId]);
      await AuditLogger.log(
        action: 'EMPLOYEE_DELETE',
        entityType: 'USER',
        entityId: userId,
        userId: operatorUserId,
        reason: 'Menghapus profil pegawai $userName',
        db: db,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleActive(String userId, bool active, {String? operatorUserId}) async {
    final db = await _appDb.database;
    await db.update('users', {'is_active': active ? 1 : 0}, where: 'id = ?', whereArgs: [userId]);
    await AuditLogger.log(
      action: active ? 'EMPLOYEE_ACTIVATE' : 'EMPLOYEE_DEACTIVATE',
      entityType: 'USER',
      entityId: userId,
      userId: operatorUserId,
      reason: 'Status aktif diubah menjadi $active',
      db: db,
    );
  }
}
