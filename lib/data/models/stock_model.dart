class StockMovementModel {
  final String id;
  final String ingredientId;
  final String? ingredientName;
  final String? batchId;
  final String movementType; // PURCHASE, SALE, ADJUSTMENT, CANCELLATION, WASTE
  final double quantityChange;
  final double quantityBefore;
  final double quantityAfter;
  final String? referenceId;
  final String? reason;
  final String? userId;
  final String createdAt;

  StockMovementModel({
    required this.id,
    required this.ingredientId,
    this.ingredientName,
    this.batchId,
    required this.movementType,
    required this.quantityChange,
    required this.quantityBefore,
    required this.quantityAfter,
    this.referenceId,
    this.reason,
    this.userId,
    required this.createdAt,
  });

  factory StockMovementModel.fromMap(Map<String, dynamic> map) {
    return StockMovementModel(
      id: map['id'] as String,
      ingredientId: map['ingredient_id'] as String,
      ingredientName: map['ingredient_name'] as String?,
      batchId: map['batch_id'] as String?,
      movementType: map['movement_type'] as String,
      quantityChange: (map['quantity_change'] as num).toDouble(),
      quantityBefore: (map['quantity_before'] as num).toDouble(),
      quantityAfter: (map['quantity_after'] as num).toDouble(),
      referenceId: map['reference_id'] as String?,
      reason: map['reason'] as String?,
      userId: map['user_id'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ingredient_id': ingredientId,
      'batch_id': batchId,
      'movement_type': movementType,
      'quantity_change': quantityChange,
      'quantity_before': quantityBefore,
      'quantity_after': quantityAfter,
      'reference_id': referenceId,
      'reason': reason,
      'user_id': userId,
      'created_at': createdAt,
    };
  }
}

class StockBatchModel {
  final String id;
  final String ingredientId;
  final String? ingredientName;
  final String? batchNumber;
  final double initialQuantity;
  final double remainingQuantity;
  final double unitCost;
  final String? expiryDate;
  final String receivedDate;
  final bool isActive;

  StockBatchModel({
    required this.id,
    required this.ingredientId,
    this.ingredientName,
    this.batchNumber,
    required this.initialQuantity,
    required this.remainingQuantity,
    required this.unitCost,
    this.expiryDate,
    required this.receivedDate,
    this.isActive = true,
  });

  bool get isNearExpiry {
    if (expiryDate == null) return false;
    final exp = DateTime.tryParse(expiryDate!);
    if (exp == null) return false;
    final diff = exp.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 14; // near expiry in 14 days
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    final exp = DateTime.tryParse(expiryDate!);
    if (exp == null) return false;
    return exp.isBefore(DateTime.now());
  }

  factory StockBatchModel.fromMap(Map<String, dynamic> map) {
    return StockBatchModel(
      id: map['id'] as String,
      ingredientId: map['ingredient_id'] as String,
      ingredientName: map['ingredient_name'] as String?,
      batchNumber: map['batch_number'] as String?,
      initialQuantity: (map['initial_quantity'] as num).toDouble(),
      remainingQuantity: (map['remaining_quantity'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      expiryDate: map['expiry_date'] as String?,
      receivedDate: map['received_date'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ingredient_id': ingredientId,
      'batch_number': batchNumber,
      'initial_quantity': initialQuantity,
      'remaining_quantity': remainingQuantity,
      'unit_cost': unitCost,
      'expiry_date': expiryDate,
      'received_date': receivedDate,
      'is_active': isActive ? 1 : 0,
    };
  }
}
