import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
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
    );
    if (res.isEmpty) return null;
    return AttendanceModel.fromMap(res.first);
  }

  Future<AttendanceModel> clockIn({
    required String userId,
    required String enteredPin,
    String scheduledIn = '08:00',
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

    // Calculate lateness
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
    );

    await db.insert('attendance', attendance.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return attendance;
  }

  Future<AttendanceModel> clockOut({
    required String userId,
    required String enteredPin,
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

    final attRes = await db.query('attendance', where: 'user_id = ? AND date = ?', whereArgs: [userId, today]);
    if (attRes.isEmpty) {
      throw Exception('Belum melakukan clock-in hari ini');
    }

    await db.update(
      'attendance',
      {'clock_out': clockOutTime},
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, today],
    );

    final updated = await db.query('attendance', where: 'user_id = ? AND date = ?', whereArgs: [userId, today]);
    return AttendanceModel.fromMap(updated.first);
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
