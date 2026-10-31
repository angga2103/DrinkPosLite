import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drinkpos_lite/core/constants/app_constants.dart';
import 'package:drinkpos_lite/presentation/widgets/custom_button.dart';
import 'package:drinkpos_lite/presentation/widgets/metric_card.dart';

void main() {
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
    expect(find.text('Developed by Ansor.studi'), findsOneWidget);
    expect(find.text('Contact: 081775700114'), findsOneWidget);
    expect(find.text('Mulai Jualan'), findsOneWidget);
    expect(find.text('Omzet Hari Ini'), findsOneWidget);
    expect(find.text('Rp 1.500.000'), findsOneWidget);
  });
}
