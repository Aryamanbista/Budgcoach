import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'core/services/sms_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/incoming_share_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.initialize();
  await SmsService.initialize();

  final incomingShareService = IncomingShareService();
  await incomingShareService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        incomingShareServiceProvider.overrideWithValue(incomingShareService),
      ],
      child: const BudgcoachApp(),
    ),
  );
}

class BudgcoachApp extends ConsumerStatefulWidget {
  const BudgcoachApp({super.key});

  @override
  ConsumerState<BudgcoachApp> createState() => _BudgcoachAppState();
}

class _BudgcoachAppState extends ConsumerState<BudgcoachApp> {
  StreamSubscription<SharedStatement>? _shareSubscription;
  StreamSubscription<String>? _notificationSubscription;
  SharedStatement? _pendingStatement;
  String? _pendingNotificationRoute;

  @override
  void initState() {
    super.initState();
    final service = ref.read(incomingShareServiceProvider);
    _pendingStatement = service.takeInitialStatement();
    _shareSubscription = service.statements.listen(_openSharedStatement);
    _pendingNotificationRoute = NotificationService.takeInitialRoute();
    _notificationSubscription = NotificationService.routes.listen(
      _openNotificationRoute,
    );
  }

  void _openNotificationRoute(String route) {
    if (!ref.read(authProvider).isLoggedIn) {
      _pendingNotificationRoute = route;
      return;
    }
    _pendingNotificationRoute = null;
    ref.read(appRouterProvider).go(route);
  }

  void _openSharedStatement(SharedStatement statement) {
    if (!ref.read(authProvider).isLoggedIn) {
      _pendingStatement = statement;
      return;
    }
    _pendingStatement = null;
    ref
        .read(appRouterProvider)
        .go(
          '/home/upload',
          extra: {
            'shared_path': statement.path,
            'shared_name': statement.name,
            'shared_mime_type': statement.mimeType,
          },
        );
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider.select((state) => state.isLoggedIn), (_, loggedIn) {
      if (loggedIn) SmsService.syncPendingMessages();
      final pending = _pendingStatement;
      if (loggedIn && pending != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openSharedStatement(pending),
        );
      }
      final pendingRoute = _pendingNotificationRoute;
      if (loggedIn && pendingRoute != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openNotificationRoute(pendingRoute),
        );
      }
    });

    final appRouter = ref.watch(appRouterProvider);
    final themeMode = ref.watch(
      authProvider.select((state) => state.themeMode),
    );

    return MaterialApp.router(
      title: 'Budgcoach',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
