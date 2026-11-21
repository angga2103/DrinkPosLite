import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/services/sync_package_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/ingredient_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/promotion_model.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/ingredient_repository.dart';
import '../../../data/repositories/pos_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/shift_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state_view.dart';
import '../settings/printer_settings_screen.dart';
import '../shifts/shift_screen.dart';
import 'order_item_dialog.dart';
import 'payment_dialog.dart';
import 'receipt_preview_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final PosRepository _posRepo = PosRepository();

  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  List<IngredientModel> _lowStockIngredients = [];
  String _selectedCategoryId = 'ALL';
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupIncomingPackageListener();
  }

  void _setupIncomingPackageListener() {
    // Check initial launch intent
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialPath = await DeviceService.getIncomingPackagePath();
      if (initialPath != null && initialPath.isNotEmpty && mounted) {
        _handleIncomingFile(initialPath);
      }
    });

    // Listen to new intents while running
    const MethodChannel('com.ansorstudi.drinkpos_lite/device').setMethodCallHandler((call) async {
      if (call.method == 'onIncomingPackageReceived') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty && mounted) {
          _handleIncomingFile(path);
        }
      }
    });
  }

  void _handleIncomingFile(String path) {
    final user = ref.read(authProvider).currentUser;
    SyncPackageService.handleIncomingPackageFile(
      context,
      path,
      appliedByUserId: user?.id,
      onApplied: () {
        _loadData();
        ref.read(dashboardProvider.notifier).loadMetrics();
      },
    );
  }

  Future<void> _shareFullReportWithAudit() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final reportData = await ReportRepository().getSalesReport(
        startDate: today,
        endDate: today,
        periodTitle: 'Laporan Penjualan Hari Ini',
      );
      final auditLogs = await SettingsRepository().getAuditLogs(limit: 15);
      if (mounted) Navigator.of(context).pop();

      final currentUser = ref.read(authProvider).currentUser;
      final isCashier = currentUser?.isCashier ?? false;

      await ShareService.shareFullReportWithAuditLogs(
        report: reportData,
        auditLogs: auditLogs,
        isCashier: isCashier,
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim laporan: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cats = await _productRepo.getCategories();
    final prods = await _productRepo.getProducts(
      categoryId: _selectedCategoryId == 'ALL' ? null : _selectedCategoryId,
      query: _searchQuery,
    );
    final lowIngs = await IngredientRepository().getLowStockIngredients();

    if (mounted) {
      setState(() {
        _categories = cats;
        _products = prods;
        _lowStockIngredients = lowIngs;
        _isLoading = false;
      });
    }
  }

  Future<void> _onCategorySelected(String catId) async {
    setState(() {
      _selectedCategoryId = catId;
    });
    final prods = await _productRepo.getProducts(
      categoryId: catId == 'ALL' ? null : catId,
      query: _searchQuery,
    );
    if (mounted) setState(() => _products = prods);
  }

  Future<void> _onSearchChanged(String query) async {
    _searchQuery = query;
    final prods = await _productRepo.getProducts(
      categoryId: _selectedCategoryId == 'ALL' ? null : _selectedCategoryId,
      query: query,
    );
    if (mounted) setState(() => _products = prods);
  }

  void _showShiftClosedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.lock_clock, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Shift Kasir Tutup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Penjualan tidak diizinkan saat shift kasir tutup.\n\nSilakan buka shift kasir terlebih dahulu untuk mencatat saldo kas awal dan memulai transaksi.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShiftScreen()),
              );
            },
            child: const Text('Buka Shift Kasir'),
          ),
        ],
      ),
    );
  }

  Future<void> _addProductToCart(ProductModel product) async {
    final shiftState = ref.read(shiftProvider);
    if (!shiftState.hasActiveShift || shiftState.currentShift == null) {
      _showShiftClosedDialog();
      return;
    }

    final cartItems = await OrderItemDialog.show(context, product);
    if (cartItems != null && cartItems.isNotEmpty) {
      for (final item in cartItems) {
        ref.read(cartProvider.notifier).addItem(item);
      }
    }
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CartBottomSheetContent(
        onCheckout: () {
          Navigator.of(ctx).pop();
          _processCheckout();
        },
      ),
    );
  }

  Future<void> _processCheckout() async {
    final shiftState = ref.read(shiftProvider);
    if (!shiftState.hasActiveShift || shiftState.currentShift == null) {
      _showShiftClosedDialog();
      return;
    }

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final auth = ref.read(authProvider);
    final user = auth.currentUser;
    if (user == null) return;

    final shift = shiftState.currentShift;

    // Show Payment Dialog
    final paymentResult = await PaymentDialog.show(context, cart.finalTotal);
    if (paymentResult == null) return;

    // Show processing indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final trxItems = cart.items.map((i) {
        return i.toTransactionItemModel(transactionId: '', itemId: '');
      }).toList();

      final completedTrx = await _posRepo.createTransaction(
        cashierId: user.id,
        cashierName: user.name,
        shiftId: shift?.id,
        items: trxItems,
        totalAmount: cart.subtotal,
        discountAmount: cart.discountAmount,
        finalAmount: cart.finalTotal,
        paymentMethod: paymentResult.paymentMethod,
        cashReceived: paymentResult.cashReceived,
        qrisAmount: paymentResult.qrisAmount,
        changeAmount: paymentResult.changeAmount,
        customerId: cart.selectedCustomer?.id,
        customerName: cart.selectedCustomer?.name,
        customerPhone: cart.selectedCustomer?.phone,
      );

      // Clear cart & refresh metrics
      ref.read(cartProvider.notifier).clearCart();
      ref.read(dashboardProvider.notifier).loadMetrics();
      ref.read(shiftProvider.notifier).loadCurrentShift();

      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading dialog
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ReceiptPreviewScreen(transaction: completedTrx),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan transaksi: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showCustomerPicker() async {
    final customerRepo = CustomerRepository();
    final customers = await customerRepo.getCustomers();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerPickerModal(
        initialCustomers: customers,
        onCustomerSelected: (cust) {
          ref.read(cartProvider.notifier).setCustomer(cust);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _showParkedOrdersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ParkedOrdersBottomSheet(),
    );
  }

  void _showLowStockModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LowStockBottomSheet(
        ingredients: _lowStockIngredients,
        onRestocked: () {
          _loadData();
          ref.read(dashboardProvider.notifier).loadMetrics();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final shiftState = ref.watch(shiftProvider);
    final hasActiveShift = shiftState.hasActiveShift && shiftState.currentShift != null;

    return AppScaffold(
      title: 'Mulai Jualan (Kasir)',
      currentRoute: '/pos',
      actions: [
        if (cart.parkedOrders.isNotEmpty)
          IconButton(
            icon: Badge(
              label: Text('${cart.parkedOrders.length}'),
              backgroundColor: AppColors.secondary,
              child: const Icon(Icons.pause_circle_filled, size: 22, color: AppColors.secondary),
            ),
            tooltip: 'Antrean Ditahan (${cart.parkedOrders.length})',
            onPressed: _showParkedOrdersModal,
          ),
        if (_lowStockIngredients.isNotEmpty)
          IconButton(
            icon: Badge(
              label: Text('${_lowStockIngredients.length}'),
              backgroundColor: AppColors.danger,
              child: const Icon(Icons.warning_amber_rounded, size: 22, color: AppColors.danger),
            ),
            tooltip: '${_lowStockIngredients.length} Bahan Baku Menipis',
            onPressed: _showLowStockModal,
          ),
        IconButton(
          icon: const Icon(Icons.print_outlined, size: 20),
          tooltip: 'Pengaturan Printer Bluetooth',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.share, size: 20),
          tooltip: 'Kirim Laporan Lengkap & Audit Log',
          onPressed: _shareFullReportWithAudit,
        ),
      ],
      body: Column(
        children: [
          if (!hasActiveShift)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.dangerContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, color: AppColors.danger, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shift Kasir Masih Tutup!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.danger)),
                        Text('Penjualan dinonaktifkan. Buka shift kasir terlebih dahulu.', style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShiftScreen()));
                    },
                    child: const Text('Buka Shift', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Customer & Loyalty Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.person_pin, size: 22, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pelanggan:', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      Text(
                        cart.selectedCustomer?.name ?? 'Umum (Default)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (cart.selectedCustomer != null && cart.selectedCustomer!.stamps > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${cart.selectedCustomer!.stamps % 10}/10 ⭐',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_horiz, size: 14),
                  label: const Text('Pilih', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _showCustomerPicker,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Low Stock Alert Banner (if any)
          if (_lowStockIngredients.isNotEmpty)
            InkWell(
              onTap: _showLowStockModal,
              child: Container(
                color: AppColors.warningContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Peringatan: ${_lowStockIngredients.length} bahan baku menipis! Ketuk untuk restok.',
                        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          // Search & Category Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Search Input
                TextField(
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari nama minuman...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _onSearchChanged(''),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),

                // Category Chips (Horizontal Scroll)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _categoryChip('Semua Kategori', 'ALL'),
                      ..._categories.map((c) => _categoryChip(c.name, c.id)),
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
                        icon: Icons.local_drink_outlined,
                        title: 'Tidak Ada Menu Minuman',
                        message: 'Tidak menemukan produk untuk kategori atau kata kunci ini.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          final defaultVar = product.defaultVariant;

                          return Card(
                            margin: EdgeInsets.zero,
                            child: InkWell(
                              onTap: () => _addProductToCart(product),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Row(
                                  children: [
                                    // Drink Icon
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryContainer,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.local_cafe, color: AppColors.primary, size: 24),
                                    ),
                                    const SizedBox(width: 14),

                                    // Product details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            product.categoryName ?? 'Minuman',
                                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          if (product.variants.length > 1) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '${product.variants.length} Ukuran (${product.variants.map((v) => v.name).join(', ')})',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // Price & Add Button
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(defaultVar?.price ?? product.basePrice),
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.add, size: 14, color: Colors.white),
                                              SizedBox(width: 2),
                                              Text(
                                                'Tambah',
                                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Cart Floating Bar
          if (!cart.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Cart Info (Clickable to view items)
                    Expanded(
                      child: InkWell(
                        onTap: _showCartBottomSheet,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${cart.totalItemCount} Item dalam Keranjang',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                                const Icon(Icons.keyboard_arrow_up, size: 16, color: AppColors.textSecondary),
                              ],
                            ),
                            Text(
                              CurrencyFormatter.format(cart.finalTotal),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Hold Order Button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pause, size: 16),
                      label: const Text('Tahan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: const BorderSide(color: AppColors.secondary),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        final success = ref.read(cartProvider.notifier).parkCurrentOrder();
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pesanan berhasil ditahan ke daftar antrean.'),
                              backgroundColor: AppColors.secondary,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),

                    // Cek Pesanan & Bayar Button (Skema A)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Cek Pesanan & Bayar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _showCartBottomSheet,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String id) {
    final isSelected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primaryContainer,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (selected) {
          if (selected) _onCategorySelected(id);
        },
      ),
    );
  }
}

// Bottom sheet to view and edit cart items, apply promo
class _CartBottomSheetContent extends ConsumerWidget {
  final VoidCallback? onCheckout;

  const _CartBottomSheetContent({this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final posRepo = PosRepository();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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

          // Title & Clear
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Keranjang Belanja (${cart.totalItemCount} Cup)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.pause_circle_outline, size: 16, color: AppColors.secondary),
                    label: const Text('Tahan', style: TextStyle(color: AppColors.secondary)),
                    onPressed: () {
                      ref.read(cartProvider.notifier).parkCurrentOrder();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pesanan berhasil ditahan ke antrean!'), backgroundColor: AppColors.secondary),
                      );
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(cartProvider.notifier).clearCart();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Kosongkan', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),

          // Cart Items List
          Expanded(
            child: cart.items.isEmpty
                ? const Center(child: Text('Keranjang masih kosong'))
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final vStr = item.variantName != null ? ' (${item.variantName})' : '';

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.productName}$vStr',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  CurrencyFormatter.format(item.pricePerItem),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                for (final mod in item.modifiers)
                                  Text(
                                    '+ ${mod.name}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                if (item.notes != null)
                                  Text(
                                    'Catatan: ${item.notes}',
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          // Qty controls
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: () => ref.read(cartProvider.notifier).updateQuantity(index, -1),
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: () => ref.read(cartProvider.notifier).updateQuantity(index, 1),
                              ),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.format(item.subtotal),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          const Divider(),

          // Promo Selection Button
          FutureBuilder<List<PromotionModel>>(
            future: posRepo.getActivePromotions(),
            builder: (context, snapshot) {
              final promos = snapshot.data ?? [];
              if (promos.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Promo Diskon:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (cart.selectedPromotion != null)
                      Chip(
                        label: Text('${cart.selectedPromotion!.name} (-${CurrencyFormatter.format(cart.discountAmount)})'),
                        onDeleted: () => ref.read(cartProvider.notifier).removePromotion(),
                        backgroundColor: AppColors.secondaryContainer,
                      )
                    else
                      TextButton.icon(
                        icon: const Icon(Icons.discount_outlined, size: 16),
                        label: const Text('Pilih Promo'),
                        onPressed: () {
                          _showPromoPicker(context, ref, promos, cart.subtotal);
                        },
                      ),
                  ],
                ),
              );
            },
          ),

          // Total Calculation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text(CurrencyFormatter.format(cart.subtotal), style: const TextStyle(fontSize: 13)),
            ],
          ),
          if (cart.discountAmount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Diskon Promo:', style: TextStyle(fontSize: 13, color: AppColors.danger)),
                Text('-${CurrencyFormatter.format(cart.discountAmount)}', style: const TextStyle(fontSize: 13, color: AppColors.danger)),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Pembayaran:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(CurrencyFormatter.format(cart.finalTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons: Pay and Add More
          if (!cart.isEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment, size: 20),
                label: Text(
                  'Lanjut Pembayaran • ${CurrencyFormatter.format(cart.finalTotal)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onCheckout,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('Tambah Menu Lain'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali ke Menu'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPromoPicker(BuildContext context, WidgetRef ref, List<PromotionModel> promos, double subtotal) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Promo yang Berlaku', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...promos.map((promo) {
              final isEligible = subtotal >= promo.minPurchase;
              return ListTile(
                title: Text(promo.name),
                subtitle: Text('Min. Belanja: ${CurrencyFormatter.format(promo.minPurchase)}'),
                trailing: Text(
                  promo.isNominal ? CurrencyFormatter.format(promo.discountValue) : '${promo.discountValue.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                enabled: isEligible,
                onTap: () {
                  ref.read(cartProvider.notifier).applyPromotion(promo);
                  Navigator.of(ctx).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// Modal to pick or create customer
class _CustomerPickerModal extends StatefulWidget {
  final List<CustomerModel> initialCustomers;
  final ValueChanged<CustomerModel> onCustomerSelected;

  const _CustomerPickerModal({
    required this.initialCustomers,
    required this.onCustomerSelected,
  });

  @override
  State<_CustomerPickerModal> createState() => _CustomerPickerModalState();
}

class _CustomerPickerModalState extends State<_CustomerPickerModal> {
  final CustomerRepository _repo = CustomerRepository();
  late List<CustomerModel> _customers;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _customers = widget.initialCustomers;
  }

  Future<void> _filter(String query) async {
    final list = await _repo.getCustomers(query: query);
    setState(() => _customers = list);
  }

  Future<void> _saveNewCustomer() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final created = await _repo.saveCustomer(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );
    widget.onCustomerSelected(created);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pilih Pelanggan & Loyalty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(_isCreating ? Icons.list : Icons.person_add_alt_1),
                tooltip: _isCreating ? 'Daftar Pelanggan' : 'Tambah Baru',
                onPressed: () => setState(() => _isCreating = !_isCreating),
              ),
            ],
          ),
          const Divider(),
          if (_isCreating) ...[
            const Text('Tambah Pelanggan Baru', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Pelanggan *', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. WhatsApp / HP', prefixIcon: Icon(Icons.phone)),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Simpan & Pilih'),
                onPressed: _saveNewCustomer,
              ),
            ),
          ] else ...[
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Cari nama atau nomor HP...',
                prefixIcon: Icon(Icons.search, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _customers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final c = _customers[idx];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: c.id == 'cust_default' ? AppColors.divider : AppColors.primaryContainer,
                      child: Icon(
                        c.id == 'cust_default' ? Icons.people_outline : Icons.person,
                        color: c.id == 'cust_default' ? AppColors.textSecondary : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: c.phone != null && c.phone!.isNotEmpty ? Text('WA: ${c.phone}', style: const TextStyle(fontSize: 11)) : null,
                    trailing: c.id != 'cust_default'
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${c.stamps % 10}/10 ⭐',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                            ),
                          )
                        : null,
                    onTap: () => widget.onCustomerSelected(c),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Modal for Parked / Held Orders
class _ParkedOrdersBottomSheet extends ConsumerWidget {
  const _ParkedOrdersBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final parkedList = cart.parkedOrders;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daftar Antrean Ditahan (${parkedList.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const Divider(),
          Expanded(
            child: parkedList.isEmpty
                ? const Center(child: Text('Tidak ada antrean yang ditahan'))
                : ListView.separated(
                    itemCount: parkedList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final order = parkedList[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.secondaryContainer,
                          child: const Icon(Icons.pause, color: AppColors.secondary, size: 20),
                        ),
                        title: Text(order.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                          '${order.totalItemCount} Cup • ${CurrencyFormatter.format(order.subtotal)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                ref.read(cartProvider.notifier).recallParkedOrder(order.id);
                                Navigator.of(context).pop();
                              },
                              child: const Text('Panggil', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                              onPressed: () {
                                ref.read(cartProvider.notifier).deleteParkedOrder(order.id);
                              },
                            ),
                          ],
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

// Modal for Low Stock Alert and Quick Restock
class _LowStockBottomSheet extends StatelessWidget {
  final List<IngredientModel> ingredients;
  final VoidCallback onRestocked;

  const _LowStockBottomSheet({
    required this.ingredients,
    required this.onRestocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Text('Bahan Baku Menipis (${ingredients.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const Divider(),
          Expanded(
            child: ingredients.isEmpty
                ? const Center(child: Text('Semua stok bahan baku aman'))
                : ListView.separated(
                    itemCount: ingredients.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final ing = ingredients[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.dangerContainer,
                          child: const Icon(Icons.inventory_2_outlined, color: AppColors.danger, size: 20),
                        ),
                        title: Text(ing.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                          'Sisa: ${ing.currentStock.toStringAsFixed(1)} ${ing.unit} (Min: ${ing.minimumStock.toStringAsFixed(1)})',
                          style: const TextStyle(fontSize: 11, color: AppColors.danger),
                        ),
                        trailing: ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Restok', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            final success = await showDialog<bool>(
                              context: context,
                              builder: (_) => _QuickRestockDialog(ingredient: ing),
                            );
                            if (success == true) {
                              onRestocked();
                              Navigator.of(context).pop();
                            }
                          },
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

// Dialog for 1-Click Quick Restock
class _QuickRestockDialog extends StatefulWidget {
  final IngredientModel ingredient;

  const _QuickRestockDialog({required this.ingredient});

  @override
  State<_QuickRestockDialog> createState() => _QuickRestockDialogState();
}

class _QuickRestockDialogState extends State<_QuickRestockDialog> {
  final TextEditingController _qtyCtrl = TextEditingController(text: '10');
  bool _isSaving = false;

  Future<void> _doRestock() async {
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    if (qty <= 0) return;

    setState(() => _isSaving = true);
    try {
      await IngredientRepository().quickRestock(
        ingredientId: widget.ingredient.id,
        addedQuantity: qty,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal restok: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Restok Cepat: ${widget.ingredient.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sisa stok saat ini: ${widget.ingredient.currentStock.toStringAsFixed(1)} ${widget.ingredient.unit}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Jumlah Ditambahkan (${widget.ingredient.unit})',
              suffixText: widget.ingredient.unit,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              _chip('+1', 1),
              _chip('+5', 5),
              _chip('+10', 10),
              _chip('+50', 50),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _isSaving ? null : _doRestock,
          child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _chip(String label, double add) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        final cur = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
        setState(() => _qtyCtrl.text = (cur + add).toStringAsFixed(0));
      },
    );
  }
}
