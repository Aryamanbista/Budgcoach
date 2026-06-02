import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:budgcoach/main.dart';

void main() {
  testWidgets('Budgcoach App launch and smoke test', (WidgetTester tester) async {
    // Build our app under ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: BudgcoachApp(),
      ),
    );

    // Verify splash screen shows Budgcoach text logo
    expect(find.text('Budgcoach'), findsOneWidget);
  });
}
