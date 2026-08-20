import 'package:budgcoach/features/auth/screens/login_screen.dart';
import 'package:budgcoach/features/upload/screens/upload_screen.dart';
import 'package:budgcoach/features/upload/screens/review_transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

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
      const ProviderScope(child: MaterialApp(home: UploadScreen())),
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
    },
  );
}
