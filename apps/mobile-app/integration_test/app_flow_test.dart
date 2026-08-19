import 'package:budgcoach/core/router/app_router.dart';
import 'package:budgcoach/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('user navigates the core budgeting workflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go('/splash');
    await tester.pumpWidget(const ProviderScope(child: BudgcoachApp()));

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Recent Transactions'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search description or category...'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.upload_file_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Tap to select PDF or image'), findsOneWidget);
    await tester.tap(find.text('Tap to select PDF or image'));
    await tester.pump();
    expect(find.text('statement_june_2026_esewa.pdf'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Spending Allocation breakdown'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Monthly Income'), findsOneWidget);
    expect(find.text('Enable Notifications'), findsOneWidget);
  });
}
