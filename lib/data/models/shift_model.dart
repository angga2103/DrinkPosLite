class ShiftModel {
  final String id;
  final String userId;
  final String userName;
  final String startTime;
  final String? endTime;
  final double initialCash;
  final double totalCashSales;
  final double totalQrisSales;
  final double totalCashExpenses;
  final double expectedCash;
  final double? actualCash;
  final double? cashDifference;
  final String? differenceNote;
  final String status; // 'OPEN', 'CLOSED'

  ShiftModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.startTime,
    this.endTime,
    this.initialCash = 0.0,
    this.totalCashSales = 0.0,
    this.totalQrisSales = 0.0,
    this.totalCashExpenses = 0.0,
    this.expectedCash = 0.0,
    this.actualCash,
    this.cashDifference,
    this.differenceNote,
    this.status = 'OPEN',
  });

  bool get isOpen => status == 'OPEN';

  double calculateExpectedCash() {
    return initialCash + totalCashSales - totalCashExpenses;
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String?,
      initialCash: (map['initial_cash'] as num? ?? 0.0).toDouble(),
      totalCashSales: (map['total_cash_sales'] as num? ?? 0.0).toDouble(),
      totalQrisSales: (map['total_qris_sales'] as num? ?? 0.0).toDouble(),
      totalCashExpenses: (map['total_cash_expenses'] as num? ?? 0.0).toDouble(),
      expectedCash: (map['expected_cash'] as num? ?? 0.0).toDouble(),
      actualCash: (map['actual_cash'] as num?)?.toDouble(),
      cashDifference: (map['cash_difference'] as num?)?.toDouble(),
      differenceNote: map['difference_note'] as String?,
      status: map['status'] as String? ?? 'OPEN',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'start_time': startTime,
      'end_time': endTime,
      'initial_cash': initialCash,
      'total_cash_sales': totalCashSales,
      'total_qris_sales': totalQrisSales,
      'total_cash_expenses': totalCashExpenses,
      'expected_cash': expectedCash,
      'actual_cash': actualCash,
      'cash_difference': cashDifference,
      'difference_note': differenceNote,
      'status': status,
    };
  }
}
