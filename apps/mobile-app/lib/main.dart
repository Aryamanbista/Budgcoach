import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'core/services/sms_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await NotificationService.initialize();
  await SmsService.initialize();

  runApp(
    const ProviderScope(
      child: BudgcoachApp(),
    ),
  );
}

class BudgcoachApp extends ConsumerWidget {
  const BudgcoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp.router(
      title: 'Budgcoach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: authState.themeMode,
      routerConfig: appRouter,
    );
  }
}
