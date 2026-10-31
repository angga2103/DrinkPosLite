import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';

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
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _repo.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        if (_selectedCategoryId == null && cats.isNotEmpty) {
          _selectedCategoryId = cats.first.id;
        }

        if (widget.product != null) {
          _variants = List.from(widget.product!.variants);
        } else {
          // Default variants
          _variants = [
            ProductVariantModel(id: IdGenerator.generateId(prefix: 'var'), productId: '', name: 'Regular', price: 5000, isDefault: true),
            ProductVariantModel(id: IdGenerator.generateId(prefix: 'var'), productId: '', name: 'Large', price: 7000, isDefault: false),
          ];
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
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    const Text('Nama Minuman', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(hintText: 'Contoh: Es Teh Solo Manis'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Category
                    const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.cardBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategoryId,
                          isExpanded: true,
                          items: _categories.map((c) {
                            return DropdownMenuItem(value: c.id, child: Text(c.name));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Base Price
                    const Text('Harga Dasar (Rp)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _basePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(prefixText: 'Rp '),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Harga wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const Text('Deskripsi (Opsional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Keterangan rasa atau keunggulan menu'),
                    ),
                    const SizedBox(height: 24),

                    // Variants section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Varian Ukuran & Harga',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
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
                          margin: EdgeInsets.zero,
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
