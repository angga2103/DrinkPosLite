import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/share_service.dart';
import '../../../core/services/sync_package_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/promotion_model.dart';
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

    if (mounted) {
      setState(() {
        _categories = cats;
        _products = prods;
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

    final cartItem = await OrderItemDialog.show(context, product);
    if (cartItem != null) {
      ref.read(cartProvider.notifier).addItem(cartItem);
    }
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CartBottomSheetContent(),
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

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final shiftState = ref.watch(shiftProvider);
    final hasActiveShift = shiftState.hasActiveShift && shiftState.currentShift != null;

    return AppScaffold(
      title: 'Mulai Jualan (Kasir)',
      currentRoute: '/pos',
      actions: [
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

                    // Checkout / Pay Button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Bayar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _processCheckout,
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
  const _CartBottomSheetContent();

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
              TextButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).clearCart();
                  Navigator.of(context).pop();
                },
                child: const Text('Kosongkan', style: TextStyle(color: AppColors.danger)),
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

          // Close modal button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Lanjutkan Memilih Menu'),
            ),
          ),
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
