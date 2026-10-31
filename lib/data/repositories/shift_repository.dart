import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/utils/id_generator.dart';
import '../models/shift_model.dart';

class ShiftRepository {
  final AppDatabase _appDb;
  ShiftRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<ShiftModel?> getCurrentOpenShift({String? userId}) async {
    final db = await _appDb.database;
    String sql = "SELECT * FROM shifts WHERE status = 'OPEN'";
    final List<dynamic> args = [];
    if (userId != null) {
      sql += ' AND user_id = ?';
      args.add(userId);
    }
    sql += ' ORDER BY start_time DESC LIMIT 1';

    final res = await db.rawQuery(sql, args);
    if (res.isEmpty) return null;
    return ShiftModel.fromMap(res.first);
  }

  Future<ShiftModel> openShift({
    required String userId,
    required String userName,
    required double initialCash,
  }) async {
    final db = await _appDb.database;
    final now = DateTime.now().toIso8601String();
    final shiftId = IdGenerator.generateId(prefix: 'shf');

    final shift = ShiftModel(
      id: shiftId,
      userId: userId,
      userName: userName,
      startTime: now,
      initialCash: initialCash,
      totalCashSales: 0.0,
      totalQrisSales: 0.0,
      totalCashExpenses: 0.0,
      expectedCash: initialCash,
      status: 'OPEN',
    );

    await db.insert('shifts', shift.toMap());

    await AuditLogger.log(
      action: 'SHIFT_OPEN',
      entityType: 'SHIFT',
      entityId: shiftId,
      userId: userId,
      userName: userName,
      reason: 'Buka shift dengan modal kas awal Rp$initialCash',
      db: db,
    );

    return shift;
  }

  Future<void> closeShift({
    required String shiftId,
    required double actualCash,
    String? differenceNote,
    required String userId,
    String? userName,
  }) async {
    final db = await _appDb.database;
    final now = DateTime.now().toIso8601String();

    final res = await db.query('shifts', where: 'id = ?', whereArgs: [shiftId]);
    if (res.isEmpty) throw Exception('Shift tidak ditemukan');

    final shift = ShiftModel.fromMap(res.first);
    final expectedCash = shift.initialCash + shift.totalCashSales - shift.totalCashExpenses;
    final diff = actualCash - expectedCash;

    await db.update(
      'shifts',
      {
        'end_time': now,
        'expected_cash': expectedCash,
        'actual_cash': actualCash,
        'cash_difference': diff,
        'difference_note': differenceNote,
        'status': 'CLOSED',
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );

    await AuditLogger.log(
      action: 'SHIFT_CLOSE',
      entityType: 'SHIFT',
      entityId: shiftId,
      userId: userId,
      userName: userName,
      reason: 'Tutup shift: Kas Fisik Rp$actualCash, Ekspektasi Rp$expectedCash (Selisih: Rp$diff)',
      db: db,
    );
  }

  Future<List<ShiftModel>> getShiftHistory({int limit = 30}) async {
    final db = await _appDb.database;
    final res = await db.query('shifts', orderBy: 'start_time DESC', limit: limit);
    return res.map((m) => ShiftModel.fromMap(m)).toList();
  }
}
