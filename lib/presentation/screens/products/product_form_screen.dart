import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/modifier_group_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../modifiers/modifier_management_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductRepository _repo = ProductRepository();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _basePriceController;

  String? _selectedCategoryId;
  List<CategoryModel> _categories = [];
  List<ProductVariantModel> _variants = [];
  List<ModifierGroupModel> _allModifierGroups = [];
  final Set<String> _selectedModifierGroupNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descController = TextEditingController(text: widget.product?.description ?? '');
    _basePriceController = TextEditingController(
      text: widget.product?.basePrice.toStringAsFixed(0) ?? '5000',
    );
    _selectedCategoryId = widget.product?.categoryId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cats = await _repo.getCategories();
    final grps = await _repo.getModifierGroups(activeOnly: true);

    if (mounted) {
      setState(() {
        _categories = cats;
        _allModifierGroups = grps;

        if (_selectedCategoryId == null && cats.isNotEmpty) {
          _selectedCategoryId = cats.first.id;
        }

        if (widget.product != null) {
          _variants = List.from(widget.product!.variants);
          _selectedModifierGroupNames.clear();
          _selectedModifierGroupNames.addAll(widget.product!.modifierGroups);
        } else {
          // Default variants
          _variants = [
            ProductVariantModel(id: IdGenerator.generateId(prefix: 'var'), productId: '', name: 'Regular', price: 5000, isDefault: true),
            ProductVariantModel(id: IdGenerator.generateId(prefix: 'var'), productId: '', name: 'Large', price: 7000, isDefault: false),
          ];
          // Default untuk produk baru: centang grup bawaan jika ada
          for (final g in grps) {
            if (g.name == 'Level Gula' || g.name == 'Level Es Batu' || g.name == 'Topping Tambahan') {
              _selectedModifierGroupNames.add(g.name);
            }
          }
        }
        _isLoading = false;
      });
    }
  }

  void _addVariant() {
    setState(() {
      _variants.add(ProductVariantModel(
        id: IdGenerator.generateId(prefix: 'var'),
        productId: widget.product?.id ?? '',
        name: 'Varian ${_variants.length + 1}',
        price: double.tryParse(_basePriceController.text) ?? 5000,
        isDefault: _variants.isEmpty,
      ));
    });
  }

  void _removeVariant(int index) {
    if (_variants.length > 1) {
      setState(() {
        _variants.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimal harus ada 1 varian produk')),
      );
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori produk')),
      );
      return;
    }

    final pId = widget.product?.id ?? IdGenerator.generateId(prefix: 'prod');
    final basePrice = double.tryParse(_basePriceController.text.replaceAll('.', '')) ?? 0.0;

    final updatedVariants = _variants.map((v) {
      return ProductVariantModel(
        id: v.id,
        productId: pId,
        name: v.name,
        price: v.price,
        isDefault: v.isDefault,
      );
    }).toList();

    final productToSave = ProductModel(
      id: pId,
      categoryId: _selectedCategoryId!,
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
      basePrice: basePrice,
      variants: updatedVariants,
      modifierGroups: _selectedModifierGroupNames.toList(),
    );

    await _repo.saveProduct(product: productToSave, variants: updatedVariants);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Produk' : 'Tambah Produk Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _saveProduct,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Information
                    const Text('Informasi Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nama Produk *', hintText: 'Contoh: Es Teh Solo'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nama produk wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Kategori Produk *'),
                      items: _categories.map((c) {
                        return DropdownMenuItem(value: c.id, child: Text(c.name));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _basePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga Dasar (Rp) *', prefixText: 'Rp '),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Harga dasar wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi Produk (Opsional)',
                        hintText: 'Penjelasan rasa, isi, atau catatan resep',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Level & Topping Section (Custom per product)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Pilihan Level & Topping Produk',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.tune, size: 16),
                                  label: const Text('Kelola Master', style: TextStyle(fontSize: 12)),
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const ModifierManagementScreen()),
                                    );
                                    _loadData();
                                  },
                                ),
                              ],
                            ),
                            const Text(
                              'Centang jenis level atau topping yang ingin dimunculkan saat kasir memilih produk ini. Jika tidak dicentang, produk akan dipesan langsung tanpa opsi level/topping.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            if (_allModifierGroups.isEmpty)
                              const Text('Belum ada master level/topping.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _allModifierGroups.map((grp) {
                                  final isSelected = _selectedModifierGroupNames.contains(grp.name);
                                  return FilterChip(
                                    avatar: Icon(
                                      grp.isSingleChoice ? Icons.radio_button_checked : Icons.check_box,
                                      size: 16,
                                      color: isSelected ? AppColors.primary : Colors.grey,
                                    ),
                                    label: Text('${grp.name} (${grp.options.length} opsi)'),
                                    selected: isSelected,
                                    selectedColor: AppColors.primaryContainer,
                                    labelStyle: TextStyle(
                                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedModifierGroupNames.add(grp.name);
                                        } else {
                                          _selectedModifierGroupNames.remove(grp.name);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Variant Setup
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ukuran / Varian Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Tambah Varian'),
                          onPressed: _addVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _variants.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final v = _variants[index];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: v.name,
                                    decoration: const InputDecoration(labelText: 'Ukuran/Varian'),
                                    onChanged: (val) {
                                      _variants[index] = ProductVariantModel(
                                        id: v.id,
                                        productId: v.productId,
                                        name: val,
                                        price: v.price,
                                        isDefault: v.isDefault,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: v.price.toStringAsFixed(0),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Harga (Rp)', prefixText: 'Rp '),
                                    onChanged: (val) {
                                      final p = double.tryParse(val) ?? v.price;
                                      _variants[index] = ProductVariantModel(
                                        id: v.id,
                                        productId: v.productId,
                                        name: _variants[index].name,
                                        price: p,
                                        isDefault: v.isDefault,
                                      );
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                  onPressed: () => _removeVariant(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saveProduct,
                        child: Text(isEditing ? 'Perbarui Produk' : 'Simpan Produk Baru'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
