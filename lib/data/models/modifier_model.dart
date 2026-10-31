class ModifierModel {
  final String id;
  final String groupName; // 'Gula', 'Es', 'Topping'
  final String name; // 'Normal', 'Sedikit', 'Tanpa Gula', 'Boba'
  final double extraPrice;
  final String? ingredientId;
  final double ingredientAmount;
  final bool isActive;

  ModifierModel({
    required this.id,
    required this.groupName,
    required this.name,
    this.extraPrice = 0.0,
    this.ingredientId,
    this.ingredientAmount = 0.0,
    this.isActive = true,
  });

  factory ModifierModel.fromMap(Map<String, dynamic> map) {
    return ModifierModel(
      id: map['id'] as String,
      groupName: map['group_name'] as String,
      name: map['name'] as String,
      extraPrice: (map['extra_price'] as num? ?? 0.0).toDouble(),
      ingredientId: map['ingredient_id'] as String?,
      ingredientAmount: (map['ingredient_amount'] as num? ?? 0.0).toDouble(),
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_name': groupName,
      'name': name,
      'extra_price': extraPrice,
      'ingredient_id': ingredientId,
      'ingredient_amount': ingredientAmount,
      'is_active': isActive ? 1 : 0,
    };
  }
}
