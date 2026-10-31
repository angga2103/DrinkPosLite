class TransactionModifierModel {
  final String id;
  final String transactionItemId;
  final String? modifierId;
  final String groupName;
  final String name;
  final double extraPrice;
  final double extraCogs;

  TransactionModifierModel({
    required this.id,
    required this.transactionItemId,
    this.modifierId,
    required this.groupName,
    required this.name,
    this.extraPrice = 0.0,
    this.extraCogs = 0.0,
  });

  factory TransactionModifierModel.fromMap(Map<String, dynamic> map) {
    return TransactionModifierModel(
      id: map['id'] as String,
      transactionItemId: map['transaction_item_id'] as String,
      modifierId: map['modifier_id'] as String?,
      groupName: map['group_name'] as String,
      name: map['name'] as String,
      extraPrice: (map['extra_price'] as num? ?? 0.0).toDouble(),
      extraCogs: (map['extra_cogs'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_item_id': transactionItemId,
      'modifier_id': modifierId,
      'group_name': groupName,
      'name': name,
      'extra_price': extraPrice,
      'extra_cogs': extraCogs,
    };
  }
}

class TransactionItemModel {
  final String id;
  final String transactionId;
  final String productId;
  final String productName;
  final String? variantId;
  final String? variantName;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final double unitCogs; // HPP snapshot per cup
  final double totalCogs;
  final String? notes;
  final String? recipeSnapshotJson;
  final List<TransactionModifierModel> modifiers;

  TransactionItemModel({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    this.variantId,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.unitCogs = 0.0,
    this.totalCogs = 0.0,
    this.notes,
    this.recipeSnapshotJson,
    this.modifiers = const [],
  });

  factory TransactionItemModel.fromMap(Map<String, dynamic> map, {List<TransactionModifierModel>? modifiers}) {
    return TransactionItemModel(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      variantId: map['variant_id'] as String?,
      variantName: map['variant_name'] as String?,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      unitCogs: (map['unit_cogs'] as num? ?? 0.0).toDouble(),
      totalCogs: (map['total_cogs'] as num? ?? 0.0).toDouble(),
      notes: map['notes'] as String?,
      recipeSnapshotJson: map['recipe_snapshot_json'] as String?,
      modifiers: modifiers ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'variant_id': variantId,
      'variant_name': variantName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'unit_cogs': unitCogs,
      'total_cogs': totalCogs,
      'notes': notes,
      'recipe_snapshot_json': recipeSnapshotJson,
    };
  }
}

class PaymentModel {
  final String id;
  final String transactionId;
  final String paymentMethod;
  final double amount;
  final String? referenceNumber;
  final String createdAt;

  PaymentModel({
    required this.id,
    required this.transactionId,
    required this.paymentMethod,
    required this.amount,
    this.referenceNumber,
    required this.createdAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      paymentMethod: map['payment_method'] as String,
      amount: (map['amount'] as num).toDouble(),
      referenceNumber: map['reference_number'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'payment_method': paymentMethod,
      'amount': amount,
      'reference_number': referenceNumber,
      'created_at': createdAt,
    };
  }
}

class TransactionModel {
  final String id;
  final String transactionNumber;
  final String? storeId;
  final String? shiftId;
  final String cashierId;
  final String cashierName;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final double totalCogs; // HPP snapshot
  final double grossProfit;
  final String paymentMethod; // TUNAI, QRIS, SPLIT
  final double cashReceived;
  final double qrisAmount;
  final double changeAmount;
  final String status; // 'SELESAI', 'DIBATALKAN'
  final String? notes;
  final String createdAt;
  final String? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;
  final bool isRestocked;
  final List<TransactionItemModel> items;
  final List<PaymentModel> payments;

  TransactionModel({
    required this.id,
    required this.transactionNumber,
    this.storeId,
    this.shiftId,
    required this.cashierId,
    required this.cashierName,
    required this.totalAmount,
    this.discountAmount = 0.0,
    required this.finalAmount,
    this.totalCogs = 0.0,
    this.grossProfit = 0.0,
    required this.paymentMethod,
    this.cashReceived = 0.0,
    this.qrisAmount = 0.0,
    this.changeAmount = 0.0,
    this.status = 'SELESAI',
    this.notes,
    required this.createdAt,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.isRestocked = false,
    this.items = const [],
    this.payments = const [],
  });

  bool get isCompleted => status == 'SELESAI';
  bool get isCancelled => status == 'DIBATALKAN';

  factory TransactionModel.fromMap(
    Map<String, dynamic> map, {
    List<TransactionItemModel>? items,
    List<PaymentModel>? payments,
  }) {
    return TransactionModel(
      id: map['id'] as String,
      transactionNumber: map['transaction_number'] as String,
      storeId: map['store_id'] as String?,
      shiftId: map['shift_id'] as String?,
      cashierId: map['cashier_id'] as String,
      cashierName: map['cashier_name'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num? ?? 0.0).toDouble(),
      finalAmount: (map['final_amount'] as num).toDouble(),
      totalCogs: (map['total_cogs'] as num? ?? 0.0).toDouble(),
      grossProfit: (map['gross_profit'] as num? ?? 0.0).toDouble(),
      paymentMethod: map['payment_method'] as String,
      cashReceived: (map['cash_received'] as num? ?? 0.0).toDouble(),
      qrisAmount: (map['qris_amount'] as num? ?? 0.0).toDouble(),
      changeAmount: (map['change_amount'] as num? ?? 0.0).toDouble(),
      status: map['status'] as String? ?? 'SELESAI',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      cancelledAt: map['cancelled_at'] as String?,
      cancelledBy: map['cancelled_by'] as String?,
      cancellationReason: map['cancellation_reason'] as String?,
      isRestocked: (map['is_restocked'] as int? ?? 0) == 1,
      items: items ?? [],
      payments: payments ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_number': transactionNumber,
      'store_id': storeId,
      'shift_id': shiftId,
      'cashier_id': cashierId,
      'cashier_name': cashierName,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'total_cogs': totalCogs,
      'gross_profit': grossProfit,
      'payment_method': paymentMethod,
      'cash_received': cashReceived,
      'qris_amount': qrisAmount,
      'change_amount': changeAmount,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'cancelled_at': cancelledAt,
      'cancelled_by': cancelledBy,
      'cancellation_reason': cancellationReason,
      'is_restocked': isRestocked ? 1 : 0,
    };
  }
}
