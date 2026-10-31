import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/security/pin_security.dart';
import '../../core/utils/id_generator.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';

class AttendanceRepository {
  final AppDatabase _appDb;
  AttendanceRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<AttendanceModel?> getTodayAttendance(String userId) async {
    final db = await _appDb.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final res = await db.query(
      'attendance',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, today],
      orderBy: 'clock_in DESC',
      limit: 1,
    );
    if (res.isEmpty) return null;
    return AttendanceModel.fromMap(res.first);
  }

  Future<AttendanceModel> clockIn({
    required String userId,
    required String enteredPin,
    String scheduledIn = '08:00',
    String? photoPath,
  }) async {
    final db = await _appDb.database;
    final userRes = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (userRes.isEmpty) throw Exception('Pegawai tidak ditemukan');

    final user = UserModel.fromMap(userRes.first);
    if (!PinSecurity.verifyPin(enteredPin, user.pinHash)) {
      throw Exception('PIN salah. Silakan coba lagi.');
    }

    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final clockInTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Cegat Dobel Clock-In di Hari yang Sama
    final existing = await getTodayAttendance(userId);
    if (existing != null && existing.isClockedIn) {
      throw Exception('Pegawai ${user.name} sudah melakukan Clock-In hari ini pada pukul ${existing.clockIn}.');
    }

    // Hitung Keterlambatan
    int latenessMinutes = 0;
    try {
      final parts = scheduledIn.split(':');
      final schedHour = int.parse(parts[0]);
      final schedMinute = int.parse(parts[1]);
      final schedDateTime = DateTime(now.year, now.month, now.day, schedHour, schedMinute);
      if (now.isAfter(schedDateTime)) {
        latenessMinutes = now.difference(schedDateTime).inMinutes;
      }
    } catch (_) {}

    final status = latenessMinutes > 0 ? 'TERLAMBAT' : 'HADIR';

    final attendance = AttendanceModel(
      id: IdGenerator.generateId(prefix: 'att'),
      userId: userId,
      userName: user.name,
      date: today,
      scheduledIn: scheduledIn,
      clockIn: clockInTime,
      latenessMinutes: latenessMinutes,
      status: status,
      photoPath: photoPath,
    );

    await db.insert('attendance', attendance.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    await AuditLogger.log(
      action: 'CLOCK_IN',
      entityType: 'ATTENDANCE',
      entityId: attendance.id,
      userId: userId,
      userName: user.name,
      reason: 'Clock-In pukul $clockInTime ($status: $latenessMinutes menit)${photoPath != null ? " [Foto Selfie Terverifikasi]" : ""}',
      db: db,
    );

    return attendance;
  }

  Future<AttendanceModel> clockOut({
    required String userId,
    required String enteredPin,
    String? scheduledOut,
    String? photoPath,
  }) async {
    final db = await _appDb.database;
    final userRes = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (userRes.isEmpty) throw Exception('Pegawai tidak ditemukan');

    final user = UserModel.fromMap(userRes.first);
    if (!PinSecurity.verifyPin(enteredPin, user.pinHash)) {
      throw Exception('PIN salah. Silakan coba lagi.');
    }

    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final clockOutTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final existing = await getTodayAttendance(userId);
    if (existing == null || !existing.isClockedIn) {
      throw Exception('Pegawai ${user.name} belum melakukan Clock-In hari ini');
    }
    if (existing.isClockedOut) {
      throw Exception('Pegawai ${user.name} sudah melakukan Clock-Out hari ini pada pukul ${existing.clockOut}');
    }

    // Deteksi Pulang Cepat
    String finalStatus = existing.status;
    if (scheduledOut != null && scheduledOut.isNotEmpty) {
      try {
        final parts = scheduledOut.split(':');
        final schedHour = int.parse(parts[0]);
        final schedMinute = int.parse(parts[1]);
        final schedDateTime = DateTime(now.year, now.month, now.day, schedHour, schedMinute);
        if (now.isBefore(schedDateTime)) {
          final earlyMinutes = schedDateTime.difference(now).inMinutes;
          if (earlyMinutes > 15) {
            finalStatus = 'PULANG_CEPAT';
          }
        }
      } catch (_) {}
    }

    final updateData = <String, dynamic>{
      'clock_out': clockOutTime,
      'status': finalStatus,
    };
    if (photoPath != null && photoPath.isNotEmpty) {
      updateData['photo_path'] = photoPath;
    }

    await db.update(
      'attendance',
      updateData,
      where: 'id = ?',
      whereArgs: [existing.id],
    );

    await AuditLogger.log(
      action: 'CLOCK_OUT',
      entityType: 'ATTENDANCE',
      entityId: existing.id,
      userId: userId,
      userName: user.name,
      reason: 'Clock-Out pukul $clockOutTime ($finalStatus)${photoPath != null ? " [Foto Selfie Terverifikasi]" : ""}',
      db: db,
    );

    final updated = await db.query('attendance', where: 'id = ?', whereArgs: [existing.id]);
    return AttendanceModel.fromMap(updated.first);
  }

  /// Catat Izin / Sakit / Alpa oleh Owner
  Future<AttendanceModel> recordLeave({
    required String userId,
    required String status, // 'IZIN', 'SAKIT', 'ALPA'
    required String notes,
    required String recordedByUserId,
  }) async {
    final db = await _appDb.database;
    final userRes = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (userRes.isEmpty) throw Exception('Pegawai tidak ditemukan');

    final user = UserModel.fromMap(userRes.first);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final attendance = AttendanceModel(
      id: IdGenerator.generateId(prefix: 'att'),
      userId: userId,
      userName: user.name,
      date: today,
      status: status,
      notes: notes,
    );

    await db.insert('attendance', attendance.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    await AuditLogger.log(
      action: 'ATTENDANCE_LEAVE',
      entityType: 'ATTENDANCE',
      entityId: attendance.id,
      userId: recordedByUserId,
      reason: 'Catat $status untuk ${user.name}: $notes',
      db: db,
    );

    return attendance;
  }

  Future<List<AttendanceModel>> getAttendanceHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    int limit = 50,
  }) async {
    final db = await _appDb.database;
    String sql = 'SELECT * FROM attendance WHERE 1=1';
    final List<dynamic> args = [];

    if (userId != null && userId.isNotEmpty) {
      sql += ' AND user_id = ?';
      args.add(userId);
    }
    if (startDate != null) {
      sql += ' AND date >= ?';
      args.add(startDate.toIso8601String().substring(0, 10));
    }
    if (endDate != null) {
      sql += ' AND date <= ?';
      args.add(endDate.toIso8601String().substring(0, 10));
    }

    sql += ' ORDER BY date DESC, clock_in DESC LIMIT ?';
    args.add(limit);

    final res = await db.rawQuery(sql, args);
    return res.map((m) => AttendanceModel.fromMap(m)).toList();
  }
}
