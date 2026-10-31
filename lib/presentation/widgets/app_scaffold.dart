import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/device_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../screens/attendance/attendance_screen.dart';
import '../screens/backup/backup_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/employees/employee_list_screen.dart';
import '../screens/expenses/expense_list_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/pos/pos_screen.dart';
import '../screens/products/product_list_screen.dart';
import '../screens/purchases/purchase_list_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/printer_settings_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shifts/shift_screen.dart';
import 'confirmation_dialog.dart';

class AppScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final String currentRoute;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final shiftState = ref.watch(shiftProvider);
    final hasShift = shiftState.hasActiveShift;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // Shift status indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ShiftScreen()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasShift ? AppColors.successContainer : AppColors.dangerContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: hasShift ? AppColors.success : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasShift ? 'Shift Aktif' : 'Shift Tutup',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasShift ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Lock Button
          IconButton(
            icon: const Icon(Icons.lock_outline, size: 20),
            tooltip: 'Kunci Aplikasi',
            onPressed: () {
              ref.read(authProvider.notifier).lockApp();
            },
          ),
          if (actions != null) ...actions!,
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // User Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              color: AppColors.primary,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Text(
                      user != null && user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Pengguna',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user?.role ?? 'CASHIER',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Menu List (dynamically filtered by user permissions)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(
                    context: context,
                    icon: Icons.dashboard_outlined,
                    title: '1. Dashboard',
                    route: '/dashboard',
                    screen: const DashboardScreen(),
                  ),
                  if (user?.canAccess('pos') ?? true)
                    _drawerItem(
                      context: context,
                      icon: Icons.point_of_sale_outlined,
                      title: '2. Mulai Jualan',
                      route: '/pos',
                      screen: const PosScreen(),
                    ),
                  if (user?.canAccess('products') ?? false)
                    _drawerItem(
                      context: context,
                      icon: Icons.local_cafe_outlined,
                      title: '3. Produk dan Menu',
                      route: '/products',
                      screen: const ProductListScreen(),
                    ),
                  if (user?.canAccess('inventory') ?? false)
                    _drawerItem(
                      context: context,
                      icon: Icons.inventory_2_outlined,
                      title: '4. Stok & Resep',
                      route: '/inventory',
                      screen: const InventoryScreen(),
                    ),
                  if (user?.canAccess('purchases') ?? false)
                    _drawerItem(
                      context: context,
                      icon: Icons.shopping_cart_outlined,
                      title: '5. Pembelian Bahan',
                      route: '/purchases',
                      screen: const PurchaseListScreen(),
                    ),
                  if (user?.canAccess('expenses') ?? false)
                    _drawerItem(
                      context: context,
                      icon: Icons.account_balance_wallet_outlined,
                      title: '6. Pengeluaran',
                      route: '/expenses',
                      screen: const ExpenseListScreen(),
                    ),
                  if (user?.canAccess('employees') ?? false)
                    _drawerItem(
                      context: context,
                      icon: Icons.badge_outlined,
                      title: '7. Pegawai',
                      route: '/employees',
                      screen: const EmployeeListScreen(),
                    ),
                  if (user?.canAccess('attendance') ?? true)
                    _drawerItem(
                      context: context,
                      icon: Icons.access_time_outlined,
                      title: '8. Absensi',
                      route: '/attendance',
                      screen: const AttendanceScreen(),
                    ),
                  if (user?.canAccess('shifts') ?? false)
                    _drawerItem(
                      context: context,
                      icon: Icons.work_history_outlined,
                      title: '9. Shift dan Kas',
                      route: '/shifts',
                      screen: const ShiftScreen(),
                    ),
                  if (user?.canAccess('reports') ?? false)
                    _drawerItem(
                      context: context,
                      icon: Icons.bar_chart_outlined,
                      title: '10. Laporan',
                      route: '/reports',
                      screen: const ReportsScreen(),
                    ),
                  if (user?.canAccess('backup') ?? false)
                    _drawerItem(
                      context: context,
                      icon: Icons.backup_outlined,
                      title: '11. Backup & Restore',
                      route: '/backup',
                      screen: const BackupScreen(),
                    ),
                  // Printer Settings (Independent Bluetooth setup for Cashier & Staff)
                  if (user?.canAccess('printer') ?? true)
                    _drawerItem(
                      context: context,
                      icon: Icons.print_outlined,
                      title: 'Pengaturan Printer Bluetooth',
                      route: '/printer-settings',
                      screen: const PrinterSettingsScreen(),
                    ),
                  if (user?.canAccess('settings') ?? false)
                    _drawerItem(
                      context: context,
                      icon: Icons.settings_outlined,
                      title: '12. Pengaturan Toko & Logo',
                      route: '/settings',
                      screen: const SettingsScreen(),
                    ),
                ],
              ),
            ),

            // Attractive Logout & Exit Button (Point #8)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: InkWell(
                onTap: () async {
                  final confirmed = await ConfirmationDialog.show(
                    context,
                    title: 'Keluar Aplikasi',
                    message: 'Apakah Anda ingin logout dan menutup aplikasi DrinkPOS Lite?',
                    confirmText: 'Keluar & Tutup',
                    confirmColor: AppColors.danger,
                  );
                  if (confirmed == true) {
                    ref.read(authProvider.notifier).logout();
                    await DeviceService.exitApp();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.power_settings_new, color: AppColors.danger, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Keluar & Tutup Aplikasi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Developer Identity Footer with WhatsApp Link (Point #7)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                children: [
                  const Text(
                    '${AppConstants.appName} v1.0.0',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () => DeviceService.openWhatsApp(
                      phone: AppConstants.developerContact,
                      message: 'Halo Ansor.Studio, saya pengguna aplikasi DrinkPOS Lite.',
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.chat, size: 12, color: Color(0xFF128C7E)),
                          SizedBox(width: 4),
                          Text(
                            '${AppConstants.developedByText} • ${AppConstants.contactText}',
                            style: TextStyle(fontSize: 10, color: Color(0xFF128C7E), fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _drawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
    required Widget screen,
  }) {
    final isSelected = currentRoute == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      dense: true,
      onTap: () {
        Navigator.of(context).pop(); // Close drawer
        if (!isSelected) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => screen),
          );
        }
      },
    );
  }
}
