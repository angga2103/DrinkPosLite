import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state_view.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductRepository _repo = ProductRepository();
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  String _selectedCatId = 'ALL';
  String _query = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cats = await _repo.getCategories(activeOnly: false);
    final prods = await _repo.getProducts(
      categoryId: _selectedCatId == 'ALL' ? null : _selectedCatId,
      query: _query,
      activeOnly: false,
    );
    if (mounted) {
      setState(() {
        _categories = cats;
        _products = prods;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProduct(ProductModel p) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Hapus Produk',
      message: 'Apakah Anda yakin ingin menghapus produk "${p.name}"? Tindakan ini tidak dapat dibatalkan.',
      confirmText: 'Hapus',
      confirmColor: AppColors.danger,
    );

    if (confirmed == true) {
      await _repo.deleteProduct(p.id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Kelola Produk & Menu',
      currentRoute: '/products',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Produk', style: TextStyle(color: Colors.white)),
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          );
          if (res == true) _loadData();
        },
      ),
      body: Column(
        children: [
          // Search & Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari produk...',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (val) {
                    _query = val;
                    _loadData();
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('Semua'),
                          selected: _selectedCatId == 'ALL',
                          selectedColor: AppColors.primaryContainer,
                          onSelected: (_) {
                            setState(() => _selectedCatId = 'ALL');
                            _loadData();
                          },
                        ),
                      ),
                      ..._categories.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(c.name),
                              selected: _selectedCatId == c.id,
                              selectedColor: AppColors.primaryContainer,
                              onSelected: (_) {
                                setState(() => _selectedCatId = c.id);
                                _loadData();
                              },
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Product List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.local_cafe_outlined,
                        title: 'Belum Ada Produk',
                        message: 'Tambahkan menu minuman baru untuk mulai berjualan.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final p = _products[index];
                          final defaultVar = p.defaultVariant;
                          final cogs = p.estimatedCogs ?? 0.0;
                          final price = defaultVar?.price ?? p.basePrice;
                          final margin = price > 0 ? ((price - cogs) / price * 100) : 0;

                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.local_cafe, color: AppColors.primary),
                              ),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p.categoryName ?? "Kategori"} • ${p.variants.length} Varian',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Harga: ${CurrencyFormatter.format(price)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'HPP: ${CurrencyFormatter.format(cogs)}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.secondary),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.successContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${margin.toStringAsFixed(0)}% Margin',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    final res = await Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)),
                                    );
                                    if (res == true) _loadData();
                                  } else if (action == 'delete') {
                                    _deleteProduct(p);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit Produk')),
                                  const PopupMenuItem(value: 'delete', child: Text('Hapus Produk', style: TextStyle(color: AppColors.danger))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
