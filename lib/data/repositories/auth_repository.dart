import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/security/pin_security.dart';
import '../models/user_model.dart';

class AuthResult {
  final bool success;
  final UserModel? user;
  final String? errorMessage;
  final bool isLocked;

  AuthResult({
    required this.success,
    this.user,
    this.errorMessage,
    this.isLocked = false,
  });
}

class AuthRepository {
  final AppDatabase _appDb;
  AuthRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<List<UserModel>> getActiveUsers() async {
    final db = await _appDb.database;
    final res = await db.query(
      'users',
      where: 'is_active = 1',
      orderBy: "CASE role WHEN 'OWNER' THEN 1 WHEN 'MANAGER' THEN 2 ELSE 3 END, name ASC",
    );
    return res.map((m) => UserModel.fromMap(m)).toList();
  }

  Future<UserModel?> getUserById(String id) async {
    final db = await _appDb.database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return UserModel.fromMap(res.first);
  }

  Future<AuthResult> loginWithPin({required String userId, required String enteredPin}) async {
    final db = await _appDb.database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (res.isEmpty) {
      return AuthResult(success: false, errorMessage: 'Pengguna tidak ditemukan.');
    }

    final user = UserModel.fromMap(res.first);

    if (user.isLocked) {
      return AuthResult(
        success: false,
        user: user,
        isLocked: true,
        errorMessage: 'Akun ini terkunci karena 5x salah PIN. Hubungi Pemilik untuk membuka.',
      );
    }

    final isCorrect = PinSecurity.verifyPin(enteredPin, user.pinHash);

    if (isCorrect) {
      // Reset failed attempts on successful login
      if (user.failedAttempts > 0) {
        await db.update('users', {'failed_attempts': 0}, where: 'id = ?', whereArgs: [userId]);
      }
      return AuthResult(success: true, user: user);
    } else {
      final newFailedAttempts = user.failedAttempts + 1;
      final shouldLock = newFailedAttempts >= AppConstants.maxPinAttempts;

      await db.update(
        'users',
        {
          'failed_attempts': newFailedAttempts,
          'is_locked': shouldLock ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (shouldLock) {
        await AuditLogger.log(
          action: 'ACCOUNT_LOCKED',
          entityType: 'USER',
          entityId: userId,
          userName: user.name,
          reason: 'Akun dikunci otomatis setelah $newFailedAttempts kali salah PIN',
          db: db,
        );
        return AuthResult(
          success: false,
          isLocked: true,
          errorMessage: 'PIN salah 5 kali! Akun Anda telah dikunci. Hubungi Pemilik (Owner).',
        );
      } else {
        final remaining = AppConstants.maxPinAttempts - newFailedAttempts;
        return AuthResult(
          success: false,
          errorMessage: 'PIN salah. Sisa kesempatan: $remaining kali sebelum akun dikunci.',
        );
      }
    }
  }

  Future<bool> unlockUser({required String userId, required String ownerUserId}) async {
    final db = await _appDb.database;
    // Verify owner
    final ownerRes = await db.query('users', where: 'id = ? AND role = ?', whereArgs: [ownerUserId, AppConstants.roleOwner]);
    if (ownerRes.isEmpty) return false;

    await db.update(
      'users',
      {
        'is_locked': 0,
        'failed_attempts': 0,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );

    await AuditLogger.log(
      action: 'ACCOUNT_UNLOCKED',
      entityType: 'USER',
      entityId: userId,
      userId: ownerUserId,
      reason: 'Dibuka oleh Owner',
      db: db,
    );

    return true;
  }

  Future<bool> resetUserPin({
    required String targetUserId,
    required String newPin,
    required String requestedByUserId,
  }) async {
    final db = await _appDb.database;
    final newHash = PinSecurity.hashPin(newPin);

    await db.update(
      'users',
      {
        'pin_hash': newHash,
        'failed_attempts': 0,
        'is_locked': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [targetUserId],
    );

    await AuditLogger.log(
      action: 'PIN_RESET',
      entityType: 'USER',
      entityId: targetUserId,
      userId: requestedByUserId,
      reason: 'Reset PIN oleh pengguna yang berwenang',
      db: db,
    );

    return true;
  }
}
