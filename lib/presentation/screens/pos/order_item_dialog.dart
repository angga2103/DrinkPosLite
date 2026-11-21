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

  static Future<List<CartItem>?> show(BuildContext context, ProductModel product) {
    return showModalBottomSheet<List<CartItem>>(
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

  // Multi-Varian Quantities: variantId -> quantity
  final Map<String, int> _variantQuantities = {};
  int _singleQuantity = 1;

  List<ModifierGroupModel> _assignedGroups = [];
  final Map<String, ModifierModel> _singleSelections = {}; // groupName -> selected ModifierModel
  final Map<String, List<ModifierModel>> _multiSelections = {}; // groupName -> List<ModifierModel>
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initQuantities();
    _loadModifiers();
  }

  void _initQuantities() {
    if (widget.product.variants.isNotEmpty) {
      for (int i = 0; i < widget.product.variants.length; i++) {
        final v = widget.product.variants[i];
        // Opsi default: varian default atau varian pertama diset ke 1 cup, yang lain 0
        final isDefault = v.isDefault || (widget.product.defaultVariant == null && i == 0);
        _variantQuantities[v.id] = isDefault ? 1 : 0;
      }
      if (!_variantQuantities.values.any((q) => q > 0)) {
        _variantQuantities[widget.product.variants.first.id] = 1;
      }
    } else {
      _singleQuantity = 1;
    }
  }

  Future<void> _loadModifiers() async {
    final groups = await _productRepo.getModifiersForProduct(widget.product.id);
    if (mounted) {
      setState(() {
        _assignedGroups = groups;
        for (final group in groups) {
          if (group.isSingleChoice && group.options.isNotEmpty) {
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

  int get _totalCupCount {
    if (widget.product.variants.isEmpty) return _singleQuantity;
    return _variantQuantities.values.fold(0, (sum, q) => sum + q);
  }

  double get _extraPricePerCup {
    double extra = 0.0;
    for (final opt in _singleSelections.values) {
      extra += opt.extraPrice;
    }
    for (final list in _multiSelections.values) {
      for (final opt in list) {
        extra += opt.extraPrice;
      }
    }
    return extra;
  }

  double get _grandTotalPrice {
    final extra = _extraPricePerCup;
    if (widget.product.variants.isEmpty) {
      return (widget.product.basePrice + extra) * _singleQuantity;
    }
    double total = 0.0;
    for (final v in widget.product.variants) {
      final qty = _variantQuantities[v.id] ?? 0;
      if (qty > 0) {
        total += (v.price + extra) * qty;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final totalCups = _totalCupCount;
    final grandTotal = _grandTotalPrice;

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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Header Info
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
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 16),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Multi-Varian Stepper Baris (Skema A)
                  if (widget.product.variants.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PILIH UKURAN & JUMLAH CUP',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5),
                        ),
                        if (totalCups > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Total: $totalCups Cup',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final variant in widget.product.variants) ...[
                      Builder(
                        builder: (context) {
                          final qty = _variantQuantities[variant.id] ?? 0;
                          final isSelected = qty > 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryContainer.withValues(alpha: 0.25) : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.cardBorder,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        variant.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyFormatter.format(variant.price),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Counter tombol di kanan - Ergonomis dijangkau jempol
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 18),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        onPressed: qty > 0
                                            ? () => setState(() => _variantQuantities[variant.id] = qty - 1)
                                            : null,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(
                                          '$qty',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 18),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        color: AppColors.primary,
                                        onPressed: () => setState(() => _variantQuantities[variant.id] = qty + 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                  ] else ...[
                    // Porsi Standar (Non-Variant)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Porsi Standar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                const SizedBox(height: 2),
                                Text(CurrencyFormatter.format(widget.product.basePrice), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.primary),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                  onPressed: _singleQuantity > 1 ? () => setState(() => _singleQuantity--) : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('$_singleQuantity', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                  color: AppColors.primary,
                                  onPressed: () => setState(() => _singleQuantity++),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 2. Custom Modifier Groups
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

                  // 3. Catatan Khusus
                  const Text('Catatan Khusus Pesanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Pisah es, jangan terlalu manis, dll.',
                      prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Tombol Aksi Penuh Ramah Jempol (Full-Width Button)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: totalCups > 0 ? AppColors.primary : Colors.grey.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: totalCups > 0 ? 2 : 0,
              ),
              onPressed: totalCups > 0
                  ? () {
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

                      final List<CartItem> resultItems = [];

                      if (widget.product.variants.isEmpty) {
                        if (_singleQuantity > 0) {
                          resultItems.add(CartItem(
                            productId: widget.product.id,
                            productName: widget.product.name,
                            quantity: _singleQuantity,
                            unitPrice: widget.product.basePrice,
                            modifiers: appliedMods,
                            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                          ));
                        }
                      } else {
                        for (final v in widget.product.variants) {
                          final qty = _variantQuantities[v.id] ?? 0;
                          if (qty > 0) {
                            resultItems.add(CartItem(
                              productId: widget.product.id,
                              productName: widget.product.name,
                              variantId: v.id,
                              variantName: v.name,
                              quantity: qty,
                              unitPrice: v.price,
                              modifiers: List.from(appliedMods),
                              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                            ));
                          }
                        }
                      }

                      Navigator.of(context).pop(resultItems);
                    }
                  : null,
              child: Text(
                totalCups > 0
                    ? 'Tambah ke Keranjang • $totalCups Cup (${CurrencyFormatter.format(grandTotal)})'
                    : 'Pilih Minimal 1 Cup',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
