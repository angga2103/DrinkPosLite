class ExpenseCategoryModel {
  final String id;
  final String name;
  final bool isSystem;

  ExpenseCategoryModel({
    required this.id,
    required this.name,
    this.isSystem = false,
  });

  factory ExpenseCategoryModel.fromMap(Map<String, dynamic> map) {
    return ExpenseCategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      isSystem: (map['is_system'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_system': isSystem ? 1 : 0,
    };
  }
}

class ExpenseModel {
  final String id;
  final String? shiftId;
  final String categoryId;
  final String categoryName;
  final double amount;
  final String paymentMethod; // 'TUNAI', 'NON_TUNAI'
  final String? description;
  final String date;
  final String? createdBy;

  ExpenseModel({
    required this.id,
    this.shiftId,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    this.paymentMethod = 'TUNAI',
    this.description,
    required this.date,
    this.createdBy,
  });

  bool get isCash => paymentMethod == 'TUNAI';

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as String,
      shiftId: map['shift_id'] as String?,
      categoryId: map['category_id'] as String,
      categoryName: map['category_name'] as String? ?? 'Pengeluaran',
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String? ?? 'TUNAI',
      description: map['description'] as String?,
      date: map['date'] as String,
      createdBy: map['created_by'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shift_id': shiftId,
      'category_id': categoryId,
      'category_name': categoryName,
      'amount': amount,
      'payment_method': paymentMethod,
      'description': description,
      'date': date,
      'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
