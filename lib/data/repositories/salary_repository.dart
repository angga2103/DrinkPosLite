import 'package:sqflite/sqflite.dart';
import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/utils/id_generator.dart';
import '../models/salary_model.dart';

class SalaryRepository {
  final AppDatabase _appDb;
  SalaryRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<List<SalaryRecordModel>> getSalaryRecords({int? month, int? year}) async {
    final db = await _appDb.database;
    String sql = 'SELECT * FROM salary_records WHERE 1=1';
    final List<dynamic> args = [];

    if (month != null) {
      sql += ' AND period_month = ?';
      args.add(month);
    }
    if (year != null) {
      sql += ' AND period_year = ?';
      args.add(year);
    }
    sql += ' ORDER BY period_year DESC, period_month DESC, user_name ASC';

    final res = await db.rawQuery(sql, args);
    return res.map((m) => SalaryRecordModel.fromMap(m)).toList();
  }

  Future<void> saveSalaryRecord(SalaryRecordModel record) async {
    final db = await _appDb.database;
    await db.insert('salary_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markAsPaid({
    required String recordId,
    String? currentShiftId,
    String? operatorUserId,
    String? operatorUserName,
  }) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final res = await txn.query('salary_records', where: 'id = ?', whereArgs: [recordId]);
      if (res.isEmpty) throw Exception('Catatan gaji tidak ditemukan');

      final record = SalaryRecordModel.fromMap(res.first);
      final now = DateTime.now().toIso8601String();
      final today = now.substring(0, 10);

      // Update salary status
      await txn.update(
        'salary_records',
        {
          'status': 'PAID',
          'payment_date': today,
        },
        where: 'id = ?',
        whereArgs: [recordId],
      );

      // Look up expense category for salary
      final expCatRows = await txn.query(
        'expense_categories',
        where: 'name LIKE ? OR id = ?',
        whereArgs: ['%Gaji%', 'expcat_sal'],
        limit: 1,
      );
      final catId = expCatRows.isNotEmpty ? expCatRows.first['id'] as String : 'expcat_sal';
      final catName = expCatRows.isNotEmpty ? expCatRows.first['name'] as String : 'Gaji Pegawai';

      // Insert expense record
      await txn.insert('expenses', {
        'id': IdGenerator.generateId(prefix: 'exp'),
        'shift_id': currentShiftId,
        'category_id': catId,
        'category_name': catName,
        'amount': record.netSalary,
        'payment_method': 'TUNAI',
        'description': 'Pembayaran gaji ${record.userName} (Periode ${record.periodMonth}/${record.periodYear})',
        'date': today,
        'created_by': operatorUserName ?? 'Owner',
        'created_at': now,
      });

      // If there is an open shift, update shift cash expense
      if (currentShiftId != null) {
        await txn.rawUpdate('''
          UPDATE shifts
          SET total_cash_expenses = total_cash_expenses + ?,
              expected_cash = initial_cash + total_cash_sales - (total_cash_expenses + ?)
          WHERE id = ? AND status = 'OPEN'
        ''', [record.netSalary, record.netSalary, currentShiftId]);
      }

      await AuditLogger.log(
        action: 'SALARY_PAID',
        entityType: 'SALARY',
        entityId: recordId,
        userId: operatorUserId,
        userName: operatorUserName,
        reason: 'Bayar gaji ${record.userName} Rp${record.netSalary}',
        db: txn,
      );
    });
  }
}
