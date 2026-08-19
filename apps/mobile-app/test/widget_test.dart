import 'package:budgcoach/core/router/app_router.dart';
import 'package:budgcoach/features/upload/screens/upload_screen.dart';
import 'package:budgcoach/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('app launches through splash and reaches the dashboard', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go('/splash');
    await tester.pumpWidget(const ProviderScope(child: BudgcoachApp()));

    expect(find.text('Budgcoach'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.textContaining('Good morning'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);
  });

  testWidgets('statement upload enables processing after file selection', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: UploadScreen()));

    expect(find.text('Tap to select PDF or image'), findsOneWidget);
    final processButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Process Statement'),
    );
    expect(processButton.onPressed, isNull);

    await tester.tap(find.text('Tap to select PDF or image'));
    await tester.pump();

    expect(find.text('statement_june_2026_esewa.pdf'), findsOneWidget);
    final enabledButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Process Statement'),
    );
    expect(enabledButton.onPressed, isNotNull);
  });
}
