class RecipeItemModel {
  final String id;
  final String recipeId;
  final String ingredientId;
  final String? ingredientName;
  final String? unit;
  final double amountRequired;
  final double unitCost;

  RecipeItemModel({
    required this.id,
    required this.recipeId,
    required this.ingredientId,
    this.ingredientName,
    this.unit,
    required this.amountRequired,
    this.unitCost = 0.0,
  });

  double get totalItemCost => amountRequired * unitCost;

  factory RecipeItemModel.fromMap(Map<String, dynamic> map) {
    return RecipeItemModel(
      id: map['id'] as String,
      recipeId: map['recipe_id'] as String,
      ingredientId: map['ingredient_id'] as String,
      ingredientName: map['ingredient_name'] as String?,
      unit: map['unit'] as String?,
      amountRequired: (map['amount_required'] as num).toDouble(),
      unitCost: (map['cost_per_unit'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'ingredient_id': ingredientId,
      'amount_required': amountRequired,
    };
  }
}

class RecipeModel {
  final String id;
  final String productId;
  final String? variantId;
  final String name;
  final int version;
  final List<RecipeItemModel> items;

  RecipeModel({
    required this.id,
    required this.productId,
    this.variantId,
    required this.name,
    this.version = 1,
    this.items = const [],
  });

  double get calculatedCogs {
    return items.fold(0.0, (sum, item) => sum + item.totalItemCost);
  }

  factory RecipeModel.fromMap(Map<String, dynamic> map, {List<RecipeItemModel>? items}) {
    return RecipeModel(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      variantId: map['variant_id'] as String?,
      name: map['name'] as String,
      version: map['version'] as int? ?? 1,
      items: items ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'variant_id': variantId,
      'name': name,
      'version': version,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
