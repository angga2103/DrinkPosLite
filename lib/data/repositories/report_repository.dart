import '../../core/database/app_database.dart';
import '../models/ingredient_model.dart';
import '../models/report_model.dart';
import '../models/stock_model.dart';
import '../models/user_model.dart';

class ReportRepository {
  final AppDatabase _appDb;
  ReportRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<DashboardMetrics> getDashboardMetrics() async {
    final db = await _appDb.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // 1. Transactions metrics for today
    final trxRes = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_count,
        COALESCE(SUM(final_amount), 0) as total_omzet,
        COALESCE(SUM(total_cogs), 0) as total_cogs,
        COALESCE(SUM(gross_profit), 0) as total_gross_profit,
        COALESCE(SUM(qris_amount), 0) as total_qris_split,
        COALESCE(SUM(CASE WHEN payment_method = 'QRIS' THEN final_amount ELSE 0 END), 0) as total_qris_full
      FROM transactions
      WHERE status = 'SELESAI' AND substr(created_at, 1, 10) = ?
    ''', [today]);

    final trxCount = trxRes.first['total_count'] as int? ?? 0;
    final omzetToday = (trxRes.first['total_omzet'] as num? ?? 0.0).toDouble();
    final cogsToday = (trxRes.first['total_cogs'] as num? ?? 0.0).toDouble();
    final grossProfitToday = (trxRes.first['total_gross_profit'] as num? ?? 0.0).toDouble();
    final qrisToday = (trxRes.first['total_qris_full'] as num? ?? 0.0).toDouble() +
        (trxRes.first['total_qris_split'] as num? ?? 0.0).toDouble();

    // 2. Expenses today
    final expRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total_expenses
      FROM expenses
      WHERE date = ?
    ''', [today]);
    final expensesToday = (expRes.first['total_expenses'] as num? ?? 0.0).toDouble();

    // 3. Shift cash in drawer
    final shiftRes = await db.rawQuery('''
      SELECT expected_cash FROM shifts WHERE status = 'OPEN' ORDER BY start_time DESC LIMIT 1
    ''');
    final cashInDrawer = shiftRes.isNotEmpty
        ? (shiftRes.first['expected_cash'] as num? ?? 0.0).toDouble()
        : 0.0;

    // 4. Top selling products today
    final topRes = await db.rawQuery('''
      SELECT ti.product_name, SUM(ti.quantity) as total_qty, SUM(ti.subtotal) as total_sales
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.status = 'SELESAI' AND substr(t.created_at, 1, 10) = ?
      GROUP BY ti.product_name
      ORDER BY total_qty DESC
      LIMIT 5
    ''', [today]);

    // 5. Low stock ingredients
    final lowStockRes = await db.rawQuery('''
      SELECT * FROM ingredients WHERE current_stock <= minimum_stock ORDER BY current_stock ASC LIMIT 10
    ''');
    final lowStock = lowStockRes.map((m) => IngredientModel.fromMap(m)).toList();

    // 6. Near expiry batches (within 14 days)
    final batchRes = await db.rawQuery('''
      SELECT sb.*, i.name as ingredient_name
      FROM stock_batches sb
      JOIN ingredients i ON sb.ingredient_id = i.id
      WHERE sb.remaining_quantity > 0 AND sb.is_active = 1
      ORDER BY sb.expiry_date ASC
      LIMIT 10
    ''');
    final batches = batchRes.map((m) => StockBatchModel.fromMap(m)).where((b) => b.isNearExpiry || b.isExpired).toList();

    // 7. On-duty employees (clocked in today without clocking out, or open shift owner)
    final onDutyRes = await db.rawQuery('''
      SELECT DISTINCT u.*
      FROM users u
      LEFT JOIN attendance a ON u.id = a.user_id AND a.date = ?
      LEFT JOIN shifts s ON u.id = s.user_id AND s.status = 'OPEN'
      WHERE (a.clock_in IS NOT NULL AND a.clock_out IS NULL) OR s.status = 'OPEN'
    ''', [today]);
    final onDutyEmployees = onDutyRes.map((m) => UserModel.fromMap(m)).toList();

    return DashboardMetrics(
      omzetToday: omzetToday,
      transactionCountToday: trxCount,
      cogsToday: cogsToday,
      grossProfitToday: grossProfitToday,
      expensesToday: expensesToday,
      cashInDrawer: cashInDrawer,
      qrisToday: qrisToday,
      topProducts: topRes,
      lowStockIngredients: lowStock,
      nearExpiryBatches: batches,
      onDutyEmployees: onDutyEmployees,
    );
  }

  Future<SalesReportData> getSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    String periodTitle = 'Laporan Penjualan',
  }) async {
    final db = await _appDb.database;

    final startDay = startDate.toIso8601String().substring(0, 10);
    final endDay = endDate.toIso8601String().substring(0, 10);

    // Store Name
    final storeRes = await db.query('stores', limit: 1);
    final storeName = storeRes.isNotEmpty ? storeRes.first['name'] as String : 'DrinkPOS Lite';

    // Transactions aggregation
    final trxSummary = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_trx,
        COALESCE(SUM(total_amount), 0) as gross_sales,
        COALESCE(SUM(discount_amount), 0) as total_discounts,
        COALESCE(SUM(final_amount), 0) as total_revenue,
        COALESCE(SUM(total_cogs), 0) as total_cogs,
        COALESCE(SUM(gross_profit), 0) as gross_profit,
        COALESCE(SUM(CASE WHEN payment_method = 'TUNAI' THEN final_amount WHEN payment_method = 'SPLIT' THEN (final_amount - qris_amount) ELSE 0 END), 0) as total_cash,
        COALESCE(SUM(CASE WHEN payment_method = 'QRIS' THEN final_amount WHEN payment_method = 'SPLIT' THEN qris_amount ELSE 0 END), 0) as total_qris
      FROM transactions
      WHERE status = 'SELESAI' AND substr(created_at, 1, 10) BETWEEN ? AND ?
    ''', [startDay, endDay]);

    final totalTrx = trxSummary.first['total_trx'] as int? ?? 0;
    final totalRevenue = (trxSummary.first['total_revenue'] as num? ?? 0.0).toDouble();
    final totalDiscounts = (trxSummary.first['total_discounts'] as num? ?? 0.0).toDouble();
    final totalCogs = (trxSummary.first['total_cogs'] as num? ?? 0.0).toDouble();
    final grossProfit = (trxSummary.first['gross_profit'] as num? ?? 0.0).toDouble();
    final totalCash = (trxSummary.first['total_cash'] as num? ?? 0.0).toDouble();
    final totalQris = (trxSummary.first['total_qris'] as num? ?? 0.0).toDouble();

    // Total Items Sold
    final itemsSoldRes = await db.rawQuery('''
      SELECT COALESCE(SUM(ti.quantity), 0) as total_qty
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.status = 'SELESAI' AND substr(t.created_at, 1, 10) BETWEEN ? AND ?
    ''', [startDay, endDay]);
    final totalItemsSold = itemsSoldRes.first['total_qty'] as int? ?? 0;

    // Expenses in period (separate operational vs salary)
    final expSummary = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(amount), 0) as total_expenses,
        COALESCE(SUM(CASE WHEN category_name LIKE '%Gaji%' THEN amount ELSE 0 END), 0) as total_salaries
      FROM expenses
      WHERE date BETWEEN ? AND ?
    ''', [startDay, endDay]);

    final totalExpenses = (expSummary.first['total_expenses'] as num? ?? 0.0).toDouble();
    final totalSalaries = (expSummary.first['total_salaries'] as num? ?? 0.0).toDouble();
    final netProfit = grossProfit - totalExpenses;

    // Top products
    final topProducts = await db.rawQuery('''
      SELECT ti.product_name, SUM(ti.quantity) as total_qty, SUM(ti.subtotal) as total_sales
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.status = 'SELESAI' AND substr(t.created_at, 1, 10) BETWEEN ? AND ?
      GROUP BY ti.product_name
      ORDER BY total_qty DESC
      LIMIT 10
    ''', [startDay, endDay]);

    // Category Sales
    final catSales = await db.rawQuery('''
      SELECT COALESCE(c.name, 'Lainnya') as category_name, SUM(ti.quantity) as total_qty, SUM(ti.subtotal) as total_sales
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      JOIN products p ON ti.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE t.status = 'SELESAI' AND substr(t.created_at, 1, 10) BETWEEN ? AND ?
      GROUP BY c.name
      ORDER BY total_sales DESC
    ''', [startDay, endDay]);

    // Detailed transactions list
    final trxList = await db.rawQuery('''
      SELECT transaction_number, created_at, cashier_name, payment_method, final_amount, status
      FROM transactions
      WHERE substr(created_at, 1, 10) BETWEEN ? AND ?
      ORDER BY created_at DESC
    ''', [startDay, endDay]);

    // Detailed expenses list
    final expList = await db.rawQuery('''
      SELECT category_name, description, amount, payment_method, date
      FROM expenses
      WHERE date BETWEEN ? AND ?
      ORDER BY date DESC
    ''', [startDay, endDay]);

    return SalesReportData(
      storeName: storeName,
      periodTitle: periodTitle,
      startDate: startDate,
      endDate: endDate,
      totalRevenue: totalRevenue,
      totalTransactions: totalTrx,
      totalItemsSold: totalItemsSold,
      totalCashSales: totalCash,
      totalQrisSales: totalQris,
      totalDiscounts: totalDiscounts,
      totalCogs: totalCogs,
      grossProfit: grossProfit,
      totalExpenses: totalExpenses,
      totalSalaries: totalSalaries,
      netProfitAfterExpenses: netProfit,
      topProducts: topProducts,
      categorySales: catSales,
      transactions: trxList,
      expensesList: expList,
    );
  }
}
