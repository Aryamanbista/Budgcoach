import 'package:budgcoach/features/auth/screens/login_screen.dart';
import 'package:budgcoach/features/auth/screens/onboarding_screen.dart';
import 'package:budgcoach/features/forecast/providers/forecast_provider.dart';
import 'package:budgcoach/features/upload/screens/upload_screen.dart';
import 'package:budgcoach/features/upload/screens/review_transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('forecast API response maps summary, chart, and learning state', () {
    final forecast = ForecastData.fromJson({
      'predicted_spend': 18500,
      'current_month_spend': 10000,
      'total_budget': 20000,
      'remaining_budget': 10000,
      'budget_breach_warning': false,
      'days_until_breach': 0,
      'ai_status': {
        'days_logged': 12,
        'required_days': 30,
        'readiness_percentage': 40,
        'active_model': 'personal_baseline',
        'learning_message': 'Budgcoach is learning your spending rhythm.',
        'coverage_status': 'verified',
        'is_fresh': true,
      },
      'history_used': [
        {'date': '2026-08-19', 'amount': 9000},
        {'date': '2026-08-20', 'amount': 10000},
      ],
      'forecast': [
        {'date': '2026-08-21', 'amount': 10850},
      ],
    });

    expect(forecast.predictedSpend, 18500);
    expect(forecast.actualPoints[20], 10000);
    expect(forecast.predictedPoints[20], 10000);
    expect(forecast.predictedPoints[21], 10850);
    expect(forecast.aiStatus.isLearning, isTrue);
    expect(forecast.aiStatus.modelLabel, 'Personal baseline');
    expect(forecast.aiStatus.coverageLabel, 'Verified & current');
  });

  testWidgets('onboarding recommends a 30-day history upload', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );

    for (var page = 0; page < 4; page++) {
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
    }

    expect(find.text('Build your personal baseline'), findsOneWidget);
    expect(find.text('30 days recommended'), findsOneWidget);
    expect(find.text('UPLOAD HISTORY'), findsOneWidget);
  });

  testWidgets(
    'authentication screen switches between sign in and registration',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginScreen())),
      );

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);

      await tester.tap(find.text('New to Budgcoach? Create an account'));
      await tester.pump();

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    },
  );

  testWidgets('statement upload requires no provider selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UploadScreen(fetchCoverageOnInit: false)),
      ),
    );

    expect(
      find.text('Budgcoach detects the statement format automatically.'),
      findsOneWidget,
    );
    expect(find.text('Select Platform'), findsNothing);
    expect(find.text('Tap to select a document'), findsOneWidget);

    final processButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Process Statement'),
    );
    expect(processButton.onPressed, isNull);
  });

  testWidgets(
    'import review excludes exact and possible duplicates by default',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final preview = <String, dynamic>{
        'batch_id': 'batch-1',
        'status': 'previewed',
        'file_reused': false,
        'new_count': 1,
        'exact_duplicates': 1,
        'possible_duplicates': 1,
        'validation_errors': 0,
        'coverage_start_date': '2026-08-01',
        'coverage_end_date': '2026-08-30',
        'coverage_days': 30,
        'transactions': [
          {
            'row_index': 0,
            'date': '2026-08-01',
            'type': 'debit',
            'amount': '1000',
            'clean_text': 'Groceries',
            'confidence': 0.98,
            'duplicate_status': 'new',
            'validation_messages': <String>[],
          },
          {
            'row_index': 1,
            'date': '2026-08-01',
            'type': 'debit',
            'amount': '1000',
            'clean_text': 'Groceries duplicate',
            'confidence': 0.96,
            'duplicate_status': 'exact',
            'validation_messages': [
              'This transaction was imported previously.',
            ],
          },
          {
            'row_index': 2,
            'date': '2026-08-01',
            'type': 'debit',
            'amount': '1000',
            'clean_text': 'Groceries similar',
            'confidence': 0.90,
            'duplicate_status': 'possible',
            'validation_messages': ['Confirm before importing.'],
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ReviewTransactionsScreen(importPreview: preview),
          ),
        ),
      );

      expect(find.text('EXACT DUPLICATE'), findsOneWidget);
      expect(find.text('POSSIBLE DUPLICATE'), findsOneWidget);
      expect(find.text('IMPORT 1 TRANSACTIONS'), findsOneWidget);
      expect(find.text('Import anyway'), findsOneWidget);
      expect(find.text('30 statement days'), findsOneWidget);
    },
  );
}
