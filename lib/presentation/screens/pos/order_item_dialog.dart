import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/modifier_group_model.dart';
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
  List<ModifierGroupModel> _assignedGroups = [];
  final Map<String, ModifierModel> _singleSelections = {}; // groupName -> selected ModifierModel
  final Map<String, List<ModifierModel>> _multiSelections = {}; // groupName -> List<ModifierModel>
  final TextEditingController _notesController = TextEditingController();
  int _quantity = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.product.defaultVariant;
    _loadModifiers();
  }

  Future<void> _loadModifiers() async {
    final groups = await _productRepo.getModifiersForProduct(widget.product.id);
    if (mounted) {
      setState(() {
        _assignedGroups = groups;
        for (final group in groups) {
          if (group.isSingleChoice && group.options.isNotEmpty) {
            // Pilih opsi default: yang mengandung 'Normal' / 'Sedang' atau opsi pertama
            final defaultOpt = group.options.firstWhere(
              (o) =>
                  o.name.toLowerCase().contains('normal') ||
                  o.name.toLowerCase().contains('sedang') ||
                  o.name.toLowerCase().contains('standar'),
              orElse: () => group.options.first,
            );
            _singleSelections[group.name] = defaultOpt;
          } else if (group.isMultipleChoice) {
            _multiSelections[group.name] = [];
          }
        }
        _isLoading = false;
      });
    }
  }

  double _calculateCurrentPrice() {
    final base = _selectedVariant?.price ?? widget.product.basePrice;
    double extra = 0.0;

    // Tambahan dari single choice (misal level rasa tertentu yang berbayar)
    for (final opt in _singleSelections.values) {
      extra += opt.extraPrice;
    }

    // Tambahan dari multi choice (misal aneka topping)
    for (final list in _multiSelections.values) {
      for (final opt in list) {
        extra += opt.extraPrice;
      }
    }

    return base + extra;
  }

  @override
  Widget build(BuildContext context) {
    final unitPrice = _calculateCurrentPrice();
    final totalPrice = unitPrice * _quantity;

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

            // 1. Variant Selection (Small, Medium, Large) jika ada lebih dari 1 varian
            if (widget.product.variants.isNotEmpty) ...[
              const Text('Ukuran / Varian', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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

            // 2. Custom Modifier Groups yang hanya berlaku untuk produk ini
            if (_isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else ...[
              for (final group in _assignedGroups) ...[
                if (group.options.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(group.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      if (group.isMultipleChoice)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text(
                            '(Bisa pilih lebih dari 1)',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (group.isSingleChoice)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.options.map((opt) {
                        final isSelected = _singleSelections[group.name]?.id == opt.id;
                        final extraStr = opt.extraPrice > 0 ? ' (+${CurrencyFormatter.format(opt.extraPrice)})' : '';
                        return ChoiceChip(
                          label: Text('${opt.name}$extraStr'),
                          selected: isSelected,
                          selectedColor: AppColors.primaryContainer,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _singleSelections[group.name] = opt);
                            }
                          },
                        );
                      }).toList(),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.options.map((opt) {
                        final list = _multiSelections[group.name] ?? [];
                        final isSelected = list.any((item) => item.id == opt.id);
                        final extraStr = opt.extraPrice > 0 ? ' (+${CurrencyFormatter.format(opt.extraPrice)})' : '';
                        return FilterChip(
                          label: Text('${opt.name}$extraStr'),
                          selected: isSelected,
                          selectedColor: AppColors.secondaryContainer,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.secondary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                list.add(opt);
                              } else {
                                list.removeWhere((item) => item.id == opt.id);
                              }
                              _multiSelections[group.name] = list;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                ],
              ],
            ],

            // 3. Special Notes
            const Text('Catatan Khusus Pesanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Contoh: Pisah es, jangan terlalu manis, dll.',
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

                      // Kumpulkan modifier dari single choice
                      for (final entry in _singleSelections.entries) {
                        final opt = entry.value;
                        appliedMods.add(TransactionModifierModel(
                          id: '',
                          transactionItemId: '',
                          modifierId: opt.id,
                          groupName: opt.groupName,
                          name: opt.name,
                          extraPrice: opt.extraPrice,
                        ));
                      }

                      // Kumpulkan modifier dari multi choice
                      for (final list in _multiSelections.values) {
                        for (final opt in list) {
                          appliedMods.add(TransactionModifierModel(
                            id: '',
                            transactionItemId: '',
                            modifierId: opt.id,
                            groupName: opt.groupName,
                            name: opt.name,
                            extraPrice: opt.extraPrice,
                          ));
                        }
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
