import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/modifier_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../providers/cart_provider.dart';

class OrderItemDialog extends StatefulWidget {
  final ProductModel product;

  const OrderItemDialog({super.key, required this.product});

  static Future<CartItem?> show(BuildContext context, ProductModel product) {
    return showModalBottomSheet<CartItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderItemDialog(product: product),
    );
  }

  @override
  State<OrderItemDialog> createState() => _OrderItemDialogState();
}

class _OrderItemDialogState extends State<OrderItemDialog> {
  final ProductRepository _productRepo = ProductRepository();

  ProductVariantModel? _selectedVariant;
  final Map<String, ModifierModel> _selectedModifiersByGroup = {};
  final List<ModifierModel> _selectedToppings = [];
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;

  List<ModifierModel> _allModifiers = [];

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.product.defaultVariant;
    _loadModifiers();
  }

  Future<void> _loadModifiers() async {
    final mods = await _productRepo.getModifiers();
    if (mounted) {
      setState(() {
        _allModifiers = mods;

        // Set default sugar & ice
        final defaultSugar = mods.firstWhere(
          (m) => m.groupName == 'Gula' && m.name.contains('Normal'),
          orElse: () => mods.firstWhere((m) => m.groupName == 'Gula', orElse: () => ModifierModel(id: '', groupName: 'Gula', name: 'Normal')),
        );
        final defaultIce = mods.firstWhere(
          (m) => m.groupName == 'Es' && m.name.contains('Normal'),
          orElse: () => mods.firstWhere((m) => m.groupName == 'Es', orElse: () => ModifierModel(id: '', groupName: 'Es', name: 'Normal')),
        );

        if (defaultSugar.id.isNotEmpty) _selectedModifiersByGroup['Gula'] = defaultSugar;
        if (defaultIce.id.isNotEmpty) _selectedModifiersByGroup['Es'] = defaultIce;
      });
    }
  }

  double _calculateCurrentPrice() {
    final base = _selectedVariant?.price ?? widget.product.basePrice;
    final toppingsTotal = _selectedToppings.fold(0.0, (s, t) => s + t.extraPrice);
    return base + toppingsTotal;
  }

  @override
  Widget build(BuildContext context) {
    final unitPrice = _calculateCurrentPrice();
    final totalPrice = unitPrice * _quantity;

    // Group modifiers
    final sugarOptions = _allModifiers.where((m) => m.groupName == 'Gula').toList();
    final iceOptions = _allModifiers.where((m) => m.groupName == 'Es').toList();
    final toppingOptions = _allModifiers.where((m) => m.groupName == 'Topping').toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Product Title & Base Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      if (widget.product.description != null && widget.product.description!.isNotEmpty)
                        Text(
                          widget.product.description!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(unitPrice),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const Divider(height: 24),

            // 1. Variant Selection (Small, Medium, Large)
            if (widget.product.variants.isNotEmpty) ...[
              const Text('Ukuran / Varian', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.product.variants.map((variant) {
                  final isSelected = _selectedVariant?.id == variant.id;
                  return ChoiceChip(
                    label: Text('${variant.name} (${CurrencyFormatter.format(variant.price)})'),
                    selected: isSelected,
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedVariant = variant);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 2. Sugar Level Selection
            if (sugarOptions.isNotEmpty) ...[
              const Text('Level Gula', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: sugarOptions.map((sugar) {
                  final isSelected = _selectedModifiersByGroup['Gula']?.id == sugar.id;
                  return ChoiceChip(
                    label: Text(sugar.name),
                    selected: isSelected,
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedModifiersByGroup['Gula'] = sugar);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Ice Level Selection
            if (iceOptions.isNotEmpty) ...[
              const Text('Level Es Batu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: iceOptions.map((ice) {
                  final isSelected = _selectedModifiersByGroup['Es']?.id == ice.id;
                  return ChoiceChip(
                    label: Text(ice.name),
                    selected: isSelected,
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedModifiersByGroup['Es'] = ice);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 4. Topping Selection (Multi-select)
            if (toppingOptions.isNotEmpty) ...[
              const Text('Topping Tambahan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: toppingOptions.map((top) {
                  final isSelected = _selectedToppings.any((t) => t.id == top.id);
                  return FilterChip(
                    label: Text('${top.name} (+${CurrencyFormatter.format(top.extraPrice)})'),
                    selected: isSelected,
                    selectedColor: AppColors.secondaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.secondary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedToppings.add(top);
                        } else {
                          _selectedToppings.removeWhere((t) => t.id == top.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 5. Special Notes
            const Text('Catatan Khusus Pesanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Contoh: Pisah es, jangan terlalu manis',
                prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            // Quantity & Add to Cart button
            Row(
              children: [
                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Submit Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final List<TransactionModifierModel> appliedMods = [];

                      // Add selected sugar
                      final sugar = _selectedModifiersByGroup['Gula'];
                      if (sugar != null) {
                        appliedMods.add(TransactionModifierModel(
                          id: '',
                          transactionItemId: '',
                          modifierId: sugar.id,
                          groupName: sugar.groupName,
                          name: sugar.name,
                          extraPrice: sugar.extraPrice,
                        ));
                      }

                      // Add selected ice
                      final ice = _selectedModifiersByGroup['Es'];
                      if (ice != null) {
                        appliedMods.add(TransactionModifierModel(
                          id: '',
                          transactionItemId: '',
                          modifierId: ice.id,
                          groupName: ice.groupName,
                          name: ice.name,
                          extraPrice: ice.extraPrice,
                        ));
                      }

                      // Add selected toppings
                      for (final top in _selectedToppings) {
                        appliedMods.add(TransactionModifierModel(
                          id: '',
                          transactionItemId: '',
                          modifierId: top.id,
                          groupName: top.groupName,
                          name: top.name,
                          extraPrice: top.extraPrice,
                        ));
                      }

                      final cartItem = CartItem(
                        productId: widget.product.id,
                        productName: widget.product.name,
                        variantId: _selectedVariant?.id,
                        variantName: _selectedVariant?.name,
                        quantity: _quantity,
                        unitPrice: _selectedVariant?.price ?? widget.product.basePrice,
                        modifiers: appliedMods,
                        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                      );

                      Navigator.of(context).pop(cartItem);
                    },
                    child: Text(
                      'Tambah • ${CurrencyFormatter.format(totalPrice)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
