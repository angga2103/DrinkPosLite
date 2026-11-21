import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drinkpos_lite/core/constants/app_constants.dart';
import 'package:drinkpos_lite/data/models/product_model.dart';
import 'package:drinkpos_lite/presentation/screens/modifiers/modifier_management_screen.dart';
import 'package:drinkpos_lite/presentation/screens/pos/order_item_dialog.dart';
import 'package:drinkpos_lite/presentation/screens/settings/printer_settings_screen.dart';
import 'package:drinkpos_lite/presentation/widgets/custom_button.dart';
import 'package:drinkpos_lite/presentation/widgets/metric_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('Core UI elements and developer branding render properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Text(AppConstants.appName),
              const Text(AppConstants.developedByText),
              const Text(AppConstants.contactText),
              CustomButton(
                text: 'Mulai Jualan',
                onPressed: () {},
              ),
              const MetricCard(
                title: 'Omzet Hari Ini',
                value: 'Rp 1.500.000',
                icon: Icons.payments,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('DrinkPOS Lite'), findsOneWidget);
    expect(find.text(AppConstants.developedByText), findsOneWidget);
    expect(find.text('Contact: 081775700114'), findsOneWidget);
    expect(find.text('Mulai Jualan'), findsOneWidget);
    expect(find.text('Omzet Hari Ini'), findsOneWidget);
    expect(find.text('Rp 1.500.000'), findsOneWidget);
  });

  testWidgets('ModifierManagementScreen compiles and renders properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ModifierManagementScreen(),
        ),
      ),
    );
    expect(find.byType(ModifierManagementScreen), findsOneWidget);
  });

  testWidgets('PrinterSettingsScreen compiles and renders dual printer sections', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PrinterSettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Pengaturan Dual Printer Thermal'), findsOneWidget);
    expect(find.text('1. Printer Kasir (Struk Konsumen)'), findsOneWidget);
    expect(find.text('2. Printer Dapur / Barista (Tiket Pesanan)'), findsOneWidget);
    expect(find.text('Aktifkan Printer Dapur Terpisah'), findsOneWidget);
  });

  testWidgets('OrderItemDialog renders multi-variant steppers and ergonomic full-width button', (WidgetTester tester) async {
    final sampleProduct = ProductModel(
      id: 'prod_test',
      name: 'Es Kopi Susu Gula Aren',
      categoryId: 'cat_coffee',
      basePrice: 15000,
      variants: [
        ProductVariantModel(id: 'var_reg', productId: 'prod_test', name: 'Regular (16oz)', price: 15000, isDefault: true),
        ProductVariantModel(id: 'var_lrg', productId: 'prod_test', name: 'Large (22oz)', price: 18000, isDefault: false),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderItemDialog(product: sampleProduct),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Es Kopi Susu Gula Aren'), findsOneWidget);
    expect(find.text('PILIH UKURAN & JUMLAH CUP'), findsOneWidget);
    expect(find.text('Regular (16oz)'), findsOneWidget);
    expect(find.text('Large (22oz)'), findsOneWidget);
    expect(find.textContaining('Tambah ke Keranjang'), findsOneWidget);
  });
}
