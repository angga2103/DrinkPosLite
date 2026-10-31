import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/app_theme.dart';
import 'core/database/app_database.dart';
import 'presentation/screens/auth/lock_screen.dart';
import 'presentation/screens/dashboard/dashboard_screen.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database
  await AppDatabase.instance.database;

  runApp(
    const ProviderScope(
      child: DrinkPosApp(),
    ),
  );
}

class DrinkPosApp extends ConsumerWidget {
  const DrinkPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        // Reset auto-lock timer on any screen touch
        ref.read(authProvider.notifier).resetInactivityTimer();
      },
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: authState.isAuthenticated ? const DashboardScreen() : const LockScreen(),
      ),
    );
  }
}
