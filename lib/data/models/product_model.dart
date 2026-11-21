class ProductVariantModel {
  final String id;
  final String productId;
  final String name; // Small, Medium, Large
  final double price;
  final bool isDefault;
  final bool isActive;

  ProductVariantModel({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    this.isDefault = false,
    this.isActive = true,
  });

  factory ProductVariantModel.fromMap(Map<String, dynamic> map) {
    return ProductVariantModel(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'price': price,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
    };
  }
}

class ProductModel {
  final String id;
  final String categoryId;
  final String? categoryName;
  final String name;
  final String? description;
  final double basePrice;
  final bool isActive;
  final String? imagePath;
  final List<ProductVariantModel> variants;
  final double? estimatedCogs; // Estimated HPP for primary variant
  final List<String> modifierGroups; // Assigned modifier group names (e.g. Level Gula, Level Es Batu)

  ProductModel({
    required this.id,
    required this.categoryId,
    this.categoryName,
    required this.name,
    this.description,
    required this.basePrice,
    this.isActive = true,
    this.imagePath,
    this.variants = const [],
    this.estimatedCogs,
    this.modifierGroups = const [],
  });

  ProductVariantModel? get defaultVariant {
    if (variants.isEmpty) return null;
    return variants.firstWhere(
      (v) => v.isDefault,
      orElse: () => variants.first,
    );
  }

  factory ProductModel.fromMap(
    Map<String, dynamic> map, {
    List<ProductVariantModel>? variants,
    double? cogs,
    List<String>? modifierGroups,
  }) {
    return ProductModel(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      categoryName: map['category_name'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      basePrice: (map['base_price'] as num? ?? 0.0).toDouble(),
      isActive: (map['is_active'] as int? ?? 1) == 1,
      imagePath: map['image_path'] as String?,
      variants: variants ?? [],
      estimatedCogs: cogs,
      modifierGroups: modifierGroups ?? [],
    );
  }

  ProductModel copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    String? name,
    String? description,
    double? basePrice,
    bool? isActive,
    String? imagePath,
    List<ProductVariantModel>? variants,
    double? estimatedCogs,
    List<String>? modifierGroups,
  }) {
    return ProductModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      isActive: isActive ?? this.isActive,
      imagePath: imagePath ?? this.imagePath,
      variants: variants ?? this.variants,
      estimatedCogs: estimatedCogs ?? this.estimatedCogs,
      modifierGroups: modifierGroups ?? this.modifierGroups,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'base_price': basePrice,
      'is_active': isActive ? 1 : 0,
      'image_path': imagePath,
    };
  }
}
