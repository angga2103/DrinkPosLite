import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drinkpos_lite/core/constants/app_constants.dart';
import 'package:drinkpos_lite/presentation/screens/modifiers/modifier_management_screen.dart';
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
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan Dual Printer Thermal'), findsOneWidget);
    expect(find.text('1. Printer Kasir (Struk Konsumen)'), findsOneWidget);
    expect(find.text('2. Printer Dapur / Barista (Tiket Pesanan)'), findsOneWidget);
    expect(find.text('Aktifkan Printer Dapur Terpisah'), findsOneWidget);
  });
}
