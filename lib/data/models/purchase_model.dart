class PurchaseItemModel {
  final String id;
  final String purchaseId;
  final String ingredientId;
  final String? ingredientName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final String? batchNumber;
  final String? expiryDate;

  PurchaseItemModel({
    required this.id,
    required this.purchaseId,
    required this.ingredientId,
    this.ingredientName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    this.batchNumber,
    this.expiryDate,
  });

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      id: map['id'] as String,
      purchaseId: map['purchase_id'] as String,
      ingredientId: map['ingredient_id'] as String,
      ingredientName: map['ingredient_name'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      totalPrice: (map['total_price'] as num).toDouble(),
      batchNumber: map['batch_number'] as String?,
      expiryDate: map['expiry_date'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'ingredient_id': ingredientId,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'batch_number': batchNumber,
      'expiry_date': expiryDate,
    };
  }
}

class PurchaseModel {
  final String id;
  final String purchaseNumber;
  final String? supplierName;
  final double totalAmount;
  final String paymentMethod;
  final String purchaseDate;
  final String? notes;
  final String? createdBy;
  final List<PurchaseItemModel> items;

  PurchaseModel({
    required this.id,
    required this.purchaseNumber,
    this.supplierName,
    required this.totalAmount,
    this.paymentMethod = 'TUNAI',
    required this.purchaseDate,
    this.notes,
    this.createdBy,
    this.items = const [],
  });

  factory PurchaseModel.fromMap(Map<String, dynamic> map, {List<PurchaseItemModel>? items}) {
    return PurchaseModel(
      id: map['id'] as String,
      purchaseNumber: map['purchase_number'] as String,
      supplierName: map['supplier_name'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String? ?? 'TUNAI',
      purchaseDate: map['purchase_date'] as String,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      items: items ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_number': purchaseNumber,
      'supplier_name': supplierName,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'purchase_date': purchaseDate,
      'notes': notes,
      'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
