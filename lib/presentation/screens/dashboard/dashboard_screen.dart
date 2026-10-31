import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/share_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/metric_card.dart';
import '../employees/employee_list_screen.dart';
import '../inventory/inventory_screen.dart';
import '../pos/pos_screen.dart';
import '../reports/reports_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).loadMetrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final m = dashboardState.metrics;
    final currentUser = ref.watch(authProvider).currentUser;
    final isCashier = currentUser?.isCashier ?? false;

    return AppScaffold(
      title: 'Dashboard Toko',
      currentRoute: '/dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Segarkan Data',
          onPressed: () => ref.read(dashboardProvider.notifier).loadMetrics(),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).loadMetrics(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary Quick Action Buttons (strictly filtered by role & permissions)
              Row(
                children: [
                  if (currentUser?.canAccess('pos') ?? true)
                    Expanded(
                      child: _quickActionButton(
                        context: context,
                        label: 'Mulai Jualan',
                        icon: Icons.point_of_sale,
                        color: AppColors.primary,
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const PosScreen()),
                        ),
                      ),
                    ),
                  if (currentUser?.canAccess('reports') ?? false) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _quickActionButton(
                        context: context,
                        label: 'Laporan',
                        icon: Icons.bar_chart,
                        color: AppColors.secondary,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReportsScreen()),
                        ),
                      ),
                    ),
                  ],
                  if (currentUser?.canAccess('inventory') ?? false) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _quickActionButton(
                        context: context,
                        label: 'Stok',
                        icon: Icons.inventory_2,
                        color: AppColors.info,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const InventoryScreen()),
                        ),
                      ),
                    ),
                  ],
                  if (currentUser?.canAccess('employees') ?? false) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _quickActionButton(
                        context: context,
                        label: 'Pegawai',
                        icon: Icons.badge,
                        color: const Color(0xFF8B5CF6),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EmployeeListScreen()),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),

              // Financial Metrics Grid (Cashier: HPP & Gross Profit hidden)
              const Text(
                'Performa Penjualan Hari Ini',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  MetricCard(
                    title: 'Omzet Hari Ini',
                    value: CurrencyFormatter.format(m.omzetToday),
                    subtitle: '${m.transactionCountToday} Transaksi Selesai',
                    icon: Icons.payments_outlined,
                    color: AppColors.primary,
                  ),
                  if (!isCashier) ...[
                    MetricCard(
                      title: 'Estimasi Laba Kotor',
                      value: CurrencyFormatter.format(m.grossProfitToday),
                      subtitle: 'Omzet dikurangi HPP',
                      icon: Icons.trending_up,
                      color: AppColors.success,
                    ),
                    MetricCard(
                      title: 'HPP (Biaya Bahan)',
                      value: CurrencyFormatter.format(m.cogsToday),
                      subtitle: 'Bahan terpakai hari ini',
                      icon: Icons.inventory_outlined,
                      color: AppColors.warning,
                    ),
                  ],
                  MetricCard(
                    title: 'Pengeluaran Hari Ini',
                    value: CurrencyFormatter.format(m.expensesToday),
                    subtitle: 'Operasional & belanja',
                    icon: Icons.money_off_outlined,
                    color: AppColors.danger,
                  ),
                  MetricCard(
                    title: 'Saldo Kas Laci',
                    value: CurrencyFormatter.format(m.cashInDrawer),
                    subtitle: 'Kas fisik shift berjalan',
                    icon: Icons.savings_outlined,
                    color: AppColors.info,
                  ),
                  MetricCard(
                    title: 'Pembayaran QRIS',
                    value: CurrencyFormatter.format(m.qrisToday),
                    subtitle: 'Total non-tunai hari ini',
                    icon: Icons.qr_code,
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Top Products Today
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Produk Terlaris Hari Ini',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${m.topProducts.length} Produk',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      if (m.topProducts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(
                            child: Text(
                              'Belum ada transaksi minuman hari ini',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: m.topProducts.length,
                          separatorBuilder: (_, __) => const Divider(height: 12),
                          itemBuilder: (context, index) {
                            final p = m.topProducts[index];
                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primaryContainer,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['product_name']?.toString() ?? '-',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        '${p['total_qty']} cup terjual',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(p['total_sales'] as num?),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Low Stock Alert Card
              if (m.lowStockIngredients.isNotEmpty) ...[
                Card(
                  color: AppColors.dangerContainer.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Peringatan: ${m.lowStockIngredients.length} Bahan Baku Menipis!',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.danger),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: m.lowStockIngredients.map((ing) {
                            return Chip(
                              label: Text('${ing.name}: ${ing.currentStock.toStringAsFixed(0)} ${ing.unit}'),
                              backgroundColor: Colors.white,
                              labelStyle: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.send, size: 16),
                            label: const Text(
                              'Pesan Bahan ke WhatsApp Supplier',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () {
                              final store = ref.read(settingsProvider).store;
                              ShareService.shareLowStockProcurementWhatsApp(
                                items: m.lowStockIngredients,
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
                const SizedBox(height: 16),
              ],

              // Near Expiry Alert Card
              if (m.nearExpiryBatches.isNotEmpty) ...[
                Card(
                  color: AppColors.warningContainer.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.warning),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.alarm, color: AppColors.secondary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Perhatian: ${m.nearExpiryBatches.length} Bahan Mendekati Kedaluwarsa!',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: m.nearExpiryBatches.map((b) {
                            return Chip(
                              label: Text('${b.ingredientName ?? "Bahan"} (Exp: ${b.expiryDate})'),
                              backgroundColor: Colors.white,
                              labelStyle: const TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.bold),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // On Duty Employees Card (Hidden for Cashier)
              if (!isCashier) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pegawai yang Sedang Bertugas',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 20),
                        if (m.onDutyEmployees.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Belum ada pegawai yang clock-in atau membuka shift hari ini',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: m.onDutyEmployees.map((emp) {
                              return Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Text(emp.name[0], style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                                label: Text('${emp.name} (${emp.role})'),
                                backgroundColor: AppColors.background,
                                side: const BorderSide(color: AppColors.cardBorder),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
