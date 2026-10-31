import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/share_service.dart';
import '../../../core/services/sync_package_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/ingredient_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/stock_model.dart';
import '../../../data/repositories/ingredient_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state_view.dart';
import 'ingredient_form_screen.dart';
import 'recipe_management_screen.dart';
import 'stock_opname_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final IngredientRepository _ingRepo = IngredientRepository();
  final ProductRepository _productRepo = ProductRepository();

  List<IngredientModel> _ingredients = [];
  List<ProductModel> _products = [];
  List<StockMovementModel> _movements = [];
  List<StockBatchModel> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final isCashier = ref.read(authProvider).currentUser?.isCashier ?? false;
    _tabController = TabController(length: isCashier ? 3 : 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final ings = await _ingRepo.getIngredients();
    final prods = await _productRepo.getProducts(activeOnly: true);
    final moves = await _ingRepo.getStockMovements();
    final bats = await _ingRepo.getBatches();

    if (mounted) {
      setState(() {
        _ingredients = ings;
        _products = prods;
        _movements = moves;
        _batches = bats;
        _isLoading = false;
      });
    }
  }

  Future<void> _shareSyncPackage() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await SyncPackageService.sharePackageToWhatsApp();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat paket: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _importSyncPackage() async {
    try {
      final pickedFile = await FilePicker.pickFile(type: FileType.any);
      if (pickedFile == null || pickedFile.path == null) return;
      final filePath = pickedFile.path!;
      final user = ref.read(authProvider).currentUser;
      if (!mounted) return;
      await SyncPackageService.handleIncomingPackageFile(
        context,
        filePath,
        appliedByUserId: user?.id,
        onApplied: _loadData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menerapkan update: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    final isCashier = user?.isCashier ?? false;
    final expectedLength = isCashier ? 3 : 4;
    if (_tabController.length != expectedLength) {
      _tabController.dispose();
      _tabController = TabController(length: expectedLength, vsync: this);
    }

    return AppScaffold(
      title: 'Inventori & Resep Stok',
      currentRoute: '/inventory',
      actions: [
        IconButton(
          icon: const Icon(Icons.sync_alt, color: Color(0xFF25D366)),
          tooltip: 'Sync WhatsApp (.dpos)',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pembaruan Jarak Jauh WhatsApp (.dpos)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    if (user?.isOwner ?? false)
                      ListTile(
                        leading: const Icon(Icons.send, color: Color(0xFF25D366)),
                        title: const Text('Kirim Pembaruan ke WA Pegawai (Owner)'),
                        subtitle: const Text('Ekspor resep, menu & stok bahan dalam berkas terenkripsi'),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _shareSyncPackage();
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined, color: AppColors.primary),
                      title: const Text('Impor Pembaruan dari WhatsApp (.dpos)'),
                      subtitle: const Text('Pilih berkas .dpos dari Owner untuk perbarui stok & resep'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _importSyncPackage();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
      floatingActionButton: isCashier
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Tambah Bahan', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final res = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IngredientFormScreen()),
                );
                if (res == true) _loadData();
              },
            ),
      body: Column(
        children: [
          // Tab bar (Cashier: 3 tabs, Owner/Manager: 4 tabs)
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              isScrollable: true,
              tabs: [
                const Tab(text: 'Stok Bahan Baku'),
                if (!isCashier) const Tab(text: 'Resep & HPP Menu'),
                const Tab(text: 'Riwayat Stok'),
                const Tab(text: 'Batch & Kedaluwarsa'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Ingredients
                      _buildIngredientsTab(user?.id ?? '', user?.name ?? '', isCashier: isCashier),
                      // Tab 2: Recipes (Owner & Manager only)
                      if (!isCashier) _buildRecipesTab(),
                      // Tab 3: Movements
                      _buildMovementsTab(),
                      // Tab 4: Batches
                      _buildBatchesTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsTab(String userId, String userName, {bool isCashier = false}) {
    if (_ingredients.isEmpty) {
      return const EmptyStateView(
        icon: Icons.inventory_2_outlined,
        title: 'Belum Ada Bahan Baku',
        message: 'Tambahkan bahan baku untuk memonitor stok dan menghitung HPP.',
      );
    }

    final lowStockItems = _ingredients.where((i) => i.isLowStock).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ingredients.length + (lowStockItems.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (lowStockItems.isNotEmpty && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: AppColors.dangerContainer.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.danger),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Peringatan: ${lowStockItems.length} Bahan Baku Menipis!',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text(
                          'Kirim Pesanan Pengadaan ke WA Supplier',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          final store = ref.read(settingsProvider).store;
                          ShareService.shareLowStockProcurementWhatsApp(
                            items: lowStockItems,
                            storeName: store.name,
                            storePhone: store.phone,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final actualIndex = lowStockItems.isNotEmpty ? index - 1 : index;
        final ing = _ingredients[actualIndex];
        final isLow = ing.isLowStock;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            ing.isPackaging ? Icons.takeout_dining_outlined : Icons.grain,
                            color: isLow ? AppColors.danger : AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ing.name,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.dangerContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'STOK MENIPIS',
                          style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sisa Stok', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text(
                          '${ing.currentStock.toStringAsFixed(1)} ${ing.unit}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isLow ? AppColors.danger : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Batas Minimum', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        Text('${ing.minimumStock.toStringAsFixed(1)} ${ing.unit}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    if (!isCashier)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Biaya / Satuan', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          Text(CurrencyFormatter.format(ing.costPerUnit), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                  ],
                ),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isLow) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send, size: 14),
                        label: const Text('Pesan WA', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          final store = ref.read(settingsProvider).store;
                          ShareService.shareLowStockProcurementWhatsApp(
                            items: [ing],
                            storeName: store.name,
                            storePhone: store.phone,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text('Opname Stok'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () async {
                        final res = await StockOpnameDialog.show(
                          context,
                          ingredient: ing,
                          userId: userId,
                          userName: userName,
                        );
                        if (res == true) _loadData();
                      },
                    ),
                    if (!isCashier) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Bahan'),
                        onPressed: () async {
                          final res = await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => IngredientFormScreen(ingredient: ing)),
                          );
                          if (res == true) _loadData();
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipesTab() {
    if (_products.isEmpty) {
      return const EmptyStateView(
        icon: Icons.local_cafe_outlined,
        title: 'Belum Ada Menu Produk',
        message: 'Tambahkan produk minuman terlebih dahulu untuk mengatur resep dan HPP.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = _products[index];
        final cogs = p.estimatedCogs ?? 0.0;
        final defaultPrice = p.defaultVariant?.price ?? p.basePrice;
        final profit = defaultPrice - cogs;
        final margin = defaultPrice > 0 ? (profit / defaultPrice * 100) : 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Harga Jual: ${CurrencyFormatter.format(defaultPrice)} • HPP: ${CurrencyFormatter.format(cogs)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Est. Laba per Cup: ${CurrencyFormatter.format(profit)} (${margin.toStringAsFixed(0)}% Margin)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.soup_kitchen, size: 16),
                  label: const Text('Atur Resep'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () async {
                    final res = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RecipeManagementScreen(product: p)),
                    );
                    if (res == true) _loadData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovementsTab() {
    if (_movements.isEmpty) {
      return const EmptyStateView(
        icon: Icons.history,
        title: 'Belum Ada Riwayat Pergerakan Stok',
        message: 'Perubahan stok otomatis dari penjualan, pembelian, atau opname akan tercatat di sini.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _movements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = _movements[index];
        final isPositive = m.quantityChange > 0;

        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: isPositive ? AppColors.successContainer : AppColors.dangerContainer,
              child: Icon(
                isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                color: isPositive ? AppColors.success : AppColors.danger,
                size: 20,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(m.ingredientName ?? 'Bahan', style: const TextStyle(fontWeight: FontWeight.bold))),
                Text(
                  '${isPositive ? "+" : ""}${m.quantityChange.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPositive ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipe: ${m.movementType} • ${m.reason ?? "-"}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Sisa Stok: ${m.quantityAfter.toStringAsFixed(1)} | ${DateFormatter.formatDateTime(DateTime.tryParse(m.createdAt))}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBatchesTab() {
    if (_batches.isEmpty) {
      return const EmptyStateView(
        icon: Icons.inventory_outlined,
        title: 'Belum Ada Batch Bahan',
        message: 'Batch bahan baku yang tercatat dari pembelian akan muncul di sini (FEFO).',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _batches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final b = _batches[index];
        final isNear = b.isNearExpiry;
        final isExpired = b.isExpired;

        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(
              isExpired ? Icons.cancel : (isNear ? Icons.warning_amber : Icons.check_circle_outline),
              color: isExpired ? AppColors.danger : (isNear ? AppColors.secondary : AppColors.success),
            ),
            title: Text('${b.ingredientName ?? "Bahan"} (${b.batchNumber ?? "-"})', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Sisa: ${b.remainingQuantity.toStringAsFixed(1)} • Tgl Masuk: ${b.receivedDate}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Exp: ${b.expiryDate ?? "-"}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isExpired ? AppColors.danger : (isNear ? AppColors.secondary : AppColors.textPrimary),
                  ),
                ),
                if (isExpired)
                  const Text('KEDALUWARSA', style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold))
                else if (isNear)
                  const Text('MENDEKATI EXP', style: TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
}
