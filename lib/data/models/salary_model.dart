class SalaryRecordModel {
  final String id;
  final String userId;
  final String userName;
  final int periodMonth;
  final int periodYear;
  final double baseSalary;
  final double bonus;
  final double deductions;
  final double netSalary;
  final String? paymentDate;
  final String status; // 'UNPAID', 'PAID'
  final String? notes;

  SalaryRecordModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.periodMonth,
    required this.periodYear,
    required this.baseSalary,
    this.bonus = 0.0,
    this.deductions = 0.0,
    required this.netSalary,
    this.paymentDate,
    this.status = 'UNPAID',
    this.notes,
  });

  bool get isPaid => status == 'PAID';

  factory SalaryRecordModel.fromMap(Map<String, dynamic> map) {
    return SalaryRecordModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      periodMonth: map['period_month'] as int,
      periodYear: map['period_year'] as int,
      baseSalary: (map['base_salary'] as num).toDouble(),
      bonus: (map['bonus'] as num? ?? 0.0).toDouble(),
      deductions: (map['deductions'] as num? ?? 0.0).toDouble(),
      netSalary: (map['net_salary'] as num).toDouble(),
      paymentDate: map['payment_date'] as String?,
      status: map['status'] as String? ?? 'UNPAID',
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'period_month': periodMonth,
      'period_year': periodYear,
      'base_salary': baseSalary,
      'bonus': bonus,
      'deductions': deductions,
      'net_salary': netSalary,
      'payment_date': paymentDate,
      'status': status,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
