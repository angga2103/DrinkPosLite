import '../../core/database/app_database.dart';
import '../../core/security/audit_logger.dart';
import '../../core/utils/id_generator.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final AppDatabase _appDb;
  ExpenseRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<List<ExpenseCategoryModel>> getCategories() async {
    final db = await _appDb.database;
    final res = await db.query('expense_categories', orderBy: 'name ASC');
    return res.map((m) => ExpenseCategoryModel.fromMap(m)).toList();
  }

  Future<void> addCategory(String name) async {
    final db = await _appDb.database;
    await db.insert('expense_categories', {
      'id': IdGenerator.generateId(prefix: 'expcat'),
      'name': name,
      'is_system': 0,
    });
  }

  Future<List<ExpenseModel>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    int limit = 100,
  }) async {
    final db = await _appDb.database;
    String sql = 'SELECT * FROM expenses WHERE 1=1';
    final List<dynamic> args = [];

    if (startDate != null) {
      sql += ' AND date >= ?';
      args.add(startDate.toIso8601String().substring(0, 10));
    }
    if (endDate != null) {
      sql += ' AND date <= ?';
      args.add(endDate.toIso8601String().substring(0, 10));
    }
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'ALL') {
      sql += ' AND category_id = ?';
      args.add(categoryId);
    }
    sql += ' ORDER BY date DESC, created_at DESC LIMIT ?';
    args.add(limit);

    final res = await db.rawQuery(sql, args);
    return res.map((m) => ExpenseModel.fromMap(m)).toList();
  }

  Future<void> saveExpense({
    required ExpenseModel expense,
    String? currentShiftId,
    String? userId,
    String? userName,
  }) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.insert('expenses', {
        ...expense.toMap(),
        'shift_id': currentShiftId,
      });

      // If cash and current shift is open, update shift cash expense
      if (expense.isCash && currentShiftId != null) {
        await txn.rawUpdate('''
          UPDATE shifts
          SET total_cash_expenses = total_cash_expenses + ?,
              expected_cash = initial_cash + total_cash_sales - (total_cash_expenses + ?)
          WHERE id = ? AND status = 'OPEN'
        ''', [expense.amount, expense.amount, currentShiftId]);
      }

      await AuditLogger.log(
        action: 'EXPENSE_CREATE',
        entityType: 'EXPENSE',
        entityId: expense.id,
        userId: userId,
        userName: userName,
        reason: 'Pengeluaran ${expense.categoryName}: Rp${expense.amount} (${expense.description ?? "-"})',
        db: txn,
      );
    });
  }

  Future<void> deleteExpense(String id, {String? userId, String? userName}) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      final expRows = await txn.query('expenses', where: 'id = ?', whereArgs: [id]);
      if (expRows.isEmpty) return;

      final exp = ExpenseModel.fromMap(expRows.first);

      // Revert shift cash if it was a cash expense and shift is still OPEN
      if (exp.isCash && exp.shiftId != null) {
        await txn.rawUpdate('''
          UPDATE shifts
          SET total_cash_expenses = total_cash_expenses - ?,
              expected_cash = initial_cash + total_cash_sales - (total_cash_expenses - ?)
          WHERE id = ? AND status = 'OPEN'
        ''', [exp.amount, exp.amount, exp.shiftId]);
      }

      await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);

      await AuditLogger.log(
        action: 'EXPENSE_DELETE',
        entityType: 'EXPENSE',
        entityId: id,
        userId: userId,
        userName: userName,
        reason: 'Hapus pengeluaran ${exp.categoryName}: Rp${exp.amount} (Kas dikembalikan ke shift)',
        db: txn,
      );
    });
  }
}
