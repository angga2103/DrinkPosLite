import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/ingredient_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/recipe_model.dart';
import '../../../data/repositories/ingredient_repository.dart';

class RecipeManagementScreen extends StatefulWidget {
  final ProductModel product;

  const RecipeManagementScreen({super.key, required this.product});

  @override
  State<RecipeManagementScreen> createState() => _RecipeManagementScreenState();
}

class _RecipeManagementScreenState extends State<RecipeManagementScreen> {
  final IngredientRepository _ingRepo = IngredientRepository();

  ProductVariantModel? _selectedVariant;
  RecipeModel? _currentRecipe;
  List<IngredientModel> _allIngredients = [];
  final List<RecipeItemModel> _recipeItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.product.defaultVariant;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final allIngs = await _ingRepo.getIngredients();
    final recipe = await _ingRepo.getRecipeForProduct(
      widget.product.id,
      variantId: _selectedVariant?.id,
    );

    if (mounted) {
      setState(() {
        _allIngredients = allIngs;
        _currentRecipe = recipe;
        _recipeItems.clear();
        if (recipe != null) {
          _recipeItems.addAll(recipe.items);
        }
        _isLoading = false;
      });
    }
  }

  double get _calculatedHpp {
    return _recipeItems.fold(0.0, (sum, item) {
      final ing = _allIngredients.firstWhere(
        (i) => i.id == item.ingredientId,
        orElse: () => IngredientModel(id: '', name: '', unit: '', currentStock: 0, costPerUnit: item.unitCost, lastBuyPrice: 0),
      );
      return sum + (item.amountRequired * ing.costPerUnit);
    });
  }

  void _addIngredientToRecipe(IngredientModel ing) {
    if (_recipeItems.any((i) => i.ingredientId == ing.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ing.name} sudah ada dalam resep ini')),
      );
      return;
    }

    setState(() {
      _recipeItems.add(RecipeItemModel(
        id: IdGenerator.generateId(prefix: 'ri'),
        recipeId: _currentRecipe?.id ?? '',
        ingredientId: ing.id,
        ingredientName: ing.name,
        unit: ing.unit,
        amountRequired: ing.isPackaging ? 1.0 : 10.0,
        unitCost: ing.costPerUnit,
      ));
    });
  }

  void _showAddIngredientModal() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Bahan untuk Ditambahkan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _allIngredients.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final ing = _allIngredients[index];
                  final alreadyAdded = _recipeItems.any((i) => i.ingredientId == ing.id);

                  return ListTile(
                    title: Text(ing.name),
                    subtitle: Text('Biaya: ${CurrencyFormatter.format(ing.costPerUnit)} / ${ing.unit}'),
                    trailing: alreadyAdded
                        ? const Icon(Icons.check, color: AppColors.success)
                        : const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    enabled: !alreadyAdded,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _addIngredientToRecipe(ing);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRecipe() async {
    final recipeId = _currentRecipe?.id ?? IdGenerator.generateId(prefix: 'rec');
    final variantName = _selectedVariant?.name ?? 'Default';

    final recipeToSave = RecipeModel(
      id: recipeId,
      productId: widget.product.id,
      variantId: _selectedVariant?.id,
      name: 'Resep ${widget.product.name} ($variantName)',
      version: _currentRecipe?.version ?? 1,
      items: _recipeItems,
    );

    await _ingRepo.saveRecipe(recipe: recipeToSave, items: _recipeItems);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resep dan HPP berhasil disimpan!'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _selectedVariant?.price ?? widget.product.basePrice;
    final hpp = _calculatedHpp;
    final profit = price - hpp;
    final margin = price > 0 ? (profit / price * 100) : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Resep & HPP: ${widget.product.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _saveRecipe,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Variant Selector & HPP Banner
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.product.variants.isNotEmpty) ...[
                        const Text('Pilih Varian Ukuran:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: widget.product.variants.map((v) {
                              final isSelected = _selectedVariant?.id == v.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ChoiceChip(
                                  label: Text('${v.name} (${CurrencyFormatter.format(v.price)})'),
                                  selected: isSelected,
                                  selectedColor: AppColors.primaryContainer,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedVariant = v);
                                      _loadData();
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // HPP vs Selling Price Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Harga Jual', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(CurrencyFormatter.format(price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(width: 1, height: 36, color: AppColors.divider),
                            Column(
                              children: [
                                const Text('HPP per Cup', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(CurrencyFormatter.format(hpp), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                              ],
                            ),
                            Container(width: 1, height: 36, color: AppColors.divider),
                            Column(
                              children: [
                                const Text('Laba Kotor (Margin)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  '${CurrencyFormatter.format(profit)} (${margin.toStringAsFixed(0)}%)',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Ingredients Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daftar Bahan Baku per 1 Porsi',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah Bahan'),
                        onPressed: _showAddIngredientModal,
                      ),
                    ],
                  ),
                ),

                // Ingredients List
                Expanded(
                  child: _recipeItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.soup_kitchen_outlined, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 8),
                              const Text('Belum ada bahan untuk resep ini', style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah Bahan Baku'),
                                onPressed: _showAddIngredientModal,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _recipeItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _recipeItems[index];
                            final ing = _allIngredients.firstWhere(
                              (i) => i.id == item.ingredientId,
                              orElse: () => IngredientModel(id: '', name: item.ingredientName ?? 'Bahan', unit: item.unit ?? 'gram', currentStock: 0, costPerUnit: item.unitCost, lastBuyPrice: 0),
                            );
                            final itemCost = item.amountRequired * ing.costPerUnit;

                            return Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ing.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text(
                                            'Biaya: ${CurrencyFormatter.format(ing.costPerUnit)} / ${ing.unit}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quantity input
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        initialValue: item.amountRequired.toStringAsFixed(1),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          suffixText: ing.unit,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                        onChanged: (val) {
                                          final amt = double.tryParse(val) ?? item.amountRequired;
                                          setState(() {
                                            _recipeItems[index] = RecipeItemModel(
                                              id: item.id,
                                              recipeId: item.recipeId,
                                              ingredientId: item.ingredientId,
                                              ingredientName: ing.name,
                                              unit: ing.unit,
                                              amountRequired: amt,
                                              unitCost: ing.costPerUnit,
                                            );
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      CurrencyFormatter.format(itemCost),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _recipeItems.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Save Button Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saveRecipe,
                        child: const Text('Simpan Resep & Perbarui HPP'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
