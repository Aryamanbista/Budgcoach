import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/transactions/screens/transactions_screen.dart';
import '../../features/transactions/screens/transaction_detail_screen.dart';
import '../../features/upload/screens/upload_screen.dart';
import '../../features/upload/screens/review_transactions_screen.dart';
import '../../features/budget/screens/budget_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/forecast/screens/forecast_screen.dart';
import '../../features/health_score/screens/health_score_screen.dart';
import '../../features/nudges/screens/nudges_screen.dart';
import '../../features/savings/screens/savings_screen.dart';
import '../../features/savings/screens/goal_detail_screen.dart';
import '../../shared/widgets/app_scaffold.dart';
import '../../features/auth/providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/splash' ||
          state.matchedLocation == '/onboarding';

      if (!authState.isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/home/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/home/upload',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return UploadScreen(
                sharedFilePath: extra?['shared_path']?.toString(),
                sharedFileName: extra?['shared_name']?.toString(),
              );
            },
          ),
          GoRoute(
            path: '/home/budget',
            builder: (context, state) => const BudgetScreen(),
          ),
          GoRoute(
            path: '/home/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/transaction/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return TransactionDetailScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/upload/review',
        builder: (context, state) => ReviewTransactionsScreen(
          importPreview:
              state.extra as Map<String, dynamic>? ?? <String, dynamic>{},
        ),
      ),
      GoRoute(
        path: '/health-score',
        builder: (context, state) => const HealthScoreScreen(),
      ),
      GoRoute(
        path: '/forecast',
        builder: (context, state) => const ForecastScreen(),
      ),
      GoRoute(
        path: '/nudges',
        builder: (context, state) => const NudgesScreen(),
      ),
      GoRoute(
        path: '/savings',
        builder: (context, state) => const SavingsScreen(),
      ),
      GoRoute(
        path: '/savings/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return GoalDetailScreen(goalId: id);
        },
      ),
    ],
  );
});
