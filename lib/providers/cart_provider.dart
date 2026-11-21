import 'package:flutter_riverpod/legacy.dart';
import '../data/models/customer_model.dart';
import '../data/models/promotion_model.dart';
import '../data/models/transaction_model.dart';

class CartItem {
  final String productId;
  final String productName;
  final String? variantId;
  final String? variantName;
  final int quantity;
  final double unitPrice;
  final List<TransactionModifierModel> modifiers;
  final String? notes;

  CartItem({
    required this.productId,
    required this.productName,
    this.variantId,
    this.variantName,
    this.quantity = 1,
    required this.unitPrice,
    this.modifiers = const [],
    this.notes,
  });

  double get extraPriceTotal => modifiers.fold(0.0, (sum, m) => sum + m.extraPrice);
  double get pricePerItem => unitPrice + extraPriceTotal;
  double get subtotal => pricePerItem * quantity;

  CartItem copyWith({
    String? productId,
    String? productName,
    String? variantId,
    String? variantName,
    int? quantity,
    double? unitPrice,
    List<TransactionModifierModel>? modifiers,
    String? notes,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantId: variantId ?? this.variantId,
      variantName: variantName ?? this.variantName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      modifiers: modifiers ?? this.modifiers,
      notes: notes ?? this.notes,
    );
  }

  TransactionItemModel toTransactionItemModel({required String transactionId, required String itemId}) {
    return TransactionItemModel(
      id: itemId,
      transactionId: transactionId,
      productId: productId,
      productName: productName,
      variantId: variantId,
      variantName: variantName,
      quantity: quantity,
      unitPrice: pricePerItem,
      subtotal: subtotal,
      notes: notes,
      modifiers: modifiers,
    );
  }
}

class ParkedOrder {
  final String id;
  final String label;
  final DateTime createdAt;
  final List<CartItem> items;
  final PromotionModel? selectedPromotion;
  final CustomerModel? selectedCustomer;

  ParkedOrder({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.items,
    this.selectedPromotion,
    this.selectedCustomer,
  });

  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);
}

class CartState {
  final List<CartItem> items;
  final PromotionModel? selectedPromotion;
  final CustomerModel? selectedCustomer;
  final List<ParkedOrder> parkedOrders;

  CartState({
    this.items = const [],
    this.selectedPromotion,
    this.selectedCustomer,
    this.parkedOrders = const [],
  });

  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);

  double get discountAmount {
    if (selectedPromotion == null) return 0.0;
    return selectedPromotion!.calculateDiscount(subtotal);
  }

  double get finalTotal {
    final res = subtotal - discountAmount;
    return res > 0 ? res : 0.0;
  }

  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    PromotionModel? selectedPromotion,
    bool clearPromotion = false,
    CustomerModel? selectedCustomer,
    bool clearCustomer = false,
    List<ParkedOrder>? parkedOrders,
  }) {
    return CartState(
      items: items ?? this.items,
      selectedPromotion: clearPromotion ? null : (selectedPromotion ?? this.selectedPromotion),
      selectedCustomer: clearCustomer ? null : (selectedCustomer ?? this.selectedCustomer),
      parkedOrders: parkedOrders ?? this.parkedOrders,
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void setCustomer(CustomerModel? customer) {
    state = state.copyWith(selectedCustomer: customer, clearCustomer: customer == null);
  }

  void addItem(CartItem newItem) {
    // Check if identical item (same product, variant, modifiers, and notes) already in cart
    final index = state.items.indexWhere((i) =>
        i.productId == newItem.productId &&
        i.variantId == newItem.variantId &&
        i.notes == newItem.notes &&
        _areModifiersEqual(i.modifiers, newItem.modifiers));

    if (index >= 0) {
      final existing = state.items[index];
      final updatedList = List<CartItem>.from(state.items);
      updatedList[index] = existing.copyWith(quantity: existing.quantity + newItem.quantity);
      state = state.copyWith(items: updatedList);
    } else {
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  bool _areModifiersEqual(List<TransactionModifierModel> a, List<TransactionModifierModel> b) {
    if (a.length != b.length) return false;
    final aNames = a.map((m) => m.name).toSet();
    final bNames = b.map((m) => m.name).toSet();
    return aNames.containsAll(bNames);
  }

  void updateQuantity(int index, int delta) {
    if (index < 0 || index >= state.items.length) return;
    final item = state.items[index];
    final newQty = item.quantity + delta;

    final updated = List<CartItem>.from(state.items);
    if (newQty <= 0) {
      updated.removeAt(index);
    } else {
      updated[index] = item.copyWith(quantity: newQty);
    }
    state = state.copyWith(items: updated);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updated = List<CartItem>.from(state.items)..removeAt(index);
    state = state.copyWith(items: updated);
  }

  void clearCart() {
    state = state.copyWith(
      items: [],
      clearPromotion: true,
      clearCustomer: true,
    );
  }

  void applyPromotion(PromotionModel promotion) {
    state = state.copyWith(selectedPromotion: promotion);
  }

  void removePromotion() {
    state = state.copyWith(clearPromotion: true);
  }

  // Hold / Park current order
  bool parkCurrentOrder({String? label}) {
    if (state.items.isEmpty) return false;

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final custName = state.selectedCustomer?.name ?? '';
    final defaultLabel = custName.isNotEmpty && custName != 'Umum (Default)'
        ? '$custName ($timeStr)'
        : 'Antrean #${state.parkedOrders.length + 1} ($timeStr)';

    final newParked = ParkedOrder(
      id: 'park_${now.millisecondsSinceEpoch}',
      label: label?.trim().isNotEmpty == true ? label!.trim() : defaultLabel,
      createdAt: now,
      items: List.from(state.items),
      selectedPromotion: state.selectedPromotion,
      selectedCustomer: state.selectedCustomer,
    );

    state = state.copyWith(
      items: [],
      clearPromotion: true,
      clearCustomer: true,
      parkedOrders: [...state.parkedOrders, newParked],
    );
    return true;
  }

  // Recall parked order back into active cart
  bool recallParkedOrder(String id) {
    final index = state.parkedOrders.indexWhere((o) => o.id == id);
    if (index < 0) return false;

    final parked = state.parkedOrders[index];
    final updatedParked = List<ParkedOrder>.from(state.parkedOrders)..removeAt(index);

    // Merge or replace into active cart
    state = state.copyWith(
      items: [...state.items, ...parked.items],
      selectedPromotion: parked.selectedPromotion ?? state.selectedPromotion,
      selectedCustomer: parked.selectedCustomer ?? state.selectedCustomer,
      parkedOrders: updatedParked,
    );
    return true;
  }

  // Delete a parked order
  void deleteParkedOrder(String id) {
    final updatedParked = state.parkedOrders.where((o) => o.id != id).toList();
    state = state.copyWith(parkedOrders: updatedParked);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
