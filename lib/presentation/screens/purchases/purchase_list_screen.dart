import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/purchase_model.dart';
import '../../../data/repositories/purchase_repository.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state_view.dart';
import 'purchase_form_screen.dart';

class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  final PurchaseRepository _repo = PurchaseRepository();
  List<PurchaseModel> _purchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final list = await _repo.getPurchases();
    if (mounted) {
      setState(() {
        _purchases = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pembelian Bahan Baku',
      currentRoute: '/purchases',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Catat Pembelian', style: TextStyle(color: Colors.white)),
        onPressed: () async {
          final res = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PurchaseFormScreen()),
          );
          if (res == true) _loadData();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _purchases.isEmpty
              ? const EmptyStateView(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Belum Ada Pembelian Bahan',
                  message: 'Catat pembelian bahan baku agar stok otomatis bertambah dan HPP selalu mutakhir.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _purchases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = _purchases[index];

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  p.purchaseNumber,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                ),
                                Text(
                                  p.purchaseDate,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Supplier: ${p.supplierName ?? "Toko / Pasar Umum"} • Metode: ${p.paymentMethod}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const Divider(height: 16),
                            // Items list summary
                            for (final item in p.items)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item.ingredientName ?? "Bahan"} (${item.quantity.toStringAsFixed(0)} ${item.unit})',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(item.totalPrice),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Pembelian:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  CurrencyFormatter.format(p.totalAmount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
