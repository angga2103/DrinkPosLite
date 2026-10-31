class IngredientModel {
  final String id;
  final String name;
  final String unit; // gram, ml, pcs, sachet
  final double currentStock;
  final double minimumStock;
  final double costPerUnit;
  final double lastBuyPrice;
  final bool isPackaging;

  IngredientModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    this.minimumStock = 10.0,
    required this.costPerUnit,
    required this.lastBuyPrice,
    this.isPackaging = false,
  });

  bool get isLowStock => currentStock <= minimumStock;

  factory IngredientModel.fromMap(Map<String, dynamic> map) {
    return IngredientModel(
      id: map['id'] as String,
      name: map['name'] as String,
      unit: map['unit'] as String,
      currentStock: (map['current_stock'] as num? ?? 0.0).toDouble(),
      minimumStock: (map['minimum_stock'] as num? ?? 10.0).toDouble(),
      costPerUnit: (map['cost_per_unit'] as num? ?? 0.0).toDouble(),
      lastBuyPrice: (map['last_buy_price'] as num? ?? 0.0).toDouble(),
      isPackaging: (map['is_packaging'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'current_stock': currentStock,
      'minimum_stock': minimumStock,
      'cost_per_unit': costPerUnit,
      'last_buy_price': lastBuyPrice,
      'is_packaging': isPackaging ? 1 : 0,
    };
  }
}
