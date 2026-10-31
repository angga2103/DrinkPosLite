class PromotionModel {
  final String id;
  final String name;
  final String promoType; // 'NOMINAL', 'PERCENTAGE'
  final double discountValue;
  final double minPurchase;
  final String? startDate;
  final String? endDate;
  final bool isActive;

  PromotionModel({
    required this.id,
    required this.name,
    required this.promoType,
    required this.discountValue,
    this.minPurchase = 0.0,
    this.startDate,
    this.endDate,
    this.isActive = true,
  });

  bool get isNominal => promoType == 'NOMINAL';
  bool get isPercentage => promoType == 'PERCENTAGE';

  double calculateDiscount(double subtotal) {
    if (!isActive) return 0.0;
    if (subtotal < minPurchase) return 0.0;

    if (startDate != null && startDate!.isNotEmpty) {
      final start = DateTime.tryParse(startDate!);
      if (start != null && DateTime.now().isBefore(start)) return 0.0;
    }
    if (endDate != null && endDate!.isNotEmpty) {
      final end = DateTime.tryParse(endDate!);
      if (end != null && DateTime.now().isAfter(end)) return 0.0;
    }

    if (isNominal) {
      return discountValue > subtotal ? subtotal : discountValue;
    } else {
      final calculated = subtotal * (discountValue / 100.0);
      return calculated > subtotal ? subtotal : calculated;
    }
  }

  factory PromotionModel.fromMap(Map<String, dynamic> map) {
    return PromotionModel(
      id: map['id'] as String,
      name: map['name'] as String,
      promoType: map['promo_type'] as String,
      discountValue: (map['discount_value'] as num).toDouble(),
      minPurchase: (map['min_purchase'] as num? ?? 0.0).toDouble(),
      startDate: map['start_date'] as String?,
      endDate: map['end_date'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'promo_type': promoType,
      'discount_value': discountValue,
      'min_purchase': minPurchase,
      'start_date': startDate,
      'end_date': endDate,
      'is_active': isActive ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
