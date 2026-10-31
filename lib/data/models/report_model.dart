import 'ingredient_model.dart';
import 'stock_model.dart';
import 'user_model.dart';

class DashboardMetrics {
  final double omzetToday;
  final int transactionCountToday;
  final double cogsToday;
  final double grossProfitToday;
  final double expensesToday;
  final double cashInDrawer;
  final double qrisToday;
  final List<Map<String, dynamic>> topProducts;
  final List<IngredientModel> lowStockIngredients;
  final List<StockBatchModel> nearExpiryBatches;
  final List<UserModel> onDutyEmployees;

  DashboardMetrics({
    this.omzetToday = 0.0,
    this.transactionCountToday = 0,
    this.cogsToday = 0.0,
    this.grossProfitToday = 0.0,
    this.expensesToday = 0.0,
    this.cashInDrawer = 0.0,
    this.qrisToday = 0.0,
    this.topProducts = const [],
    this.lowStockIngredients = const [],
    this.nearExpiryBatches = const [],
    this.onDutyEmployees = const [],
  });
}

class SalesReportData {
  final String storeName;
  final String periodTitle;
  final DateTime startDate;
  final DateTime endDate;
  final double totalRevenue; // Omzet
  final int totalTransactions;
  final int totalItemsSold;
  final double totalCashSales;
  final double totalQrisSales;
  final double totalDiscounts;
  final double totalCogs; // HPP
  final double grossProfit; // Laba kotor
  final double totalExpenses; // Pengeluaran
  final double totalSalaries; // Gaji
  final double netProfitAfterExpenses; // Estimasi laba setelah pengeluaran
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> categorySales;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> expensesList;

  SalesReportData({
    required this.storeName,
    required this.periodTitle,
    required this.startDate,
    required this.endDate,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.totalItemsSold,
    required this.totalCashSales,
    required this.totalQrisSales,
    required this.totalDiscounts,
    required this.totalCogs,
    required this.grossProfit,
    required this.totalExpenses,
    required this.totalSalaries,
    required this.netProfitAfterExpenses,
    this.topProducts = const [],
    this.categorySales = const [],
    this.transactions = const [],
    this.expensesList = const [],
  });
}
