import 'package:budgcoach/core/constants/category_constants.dart';
import 'package:budgcoach/core/mock/mock_data.dart';
import 'package:budgcoach/features/auth/providers/auth_provider.dart';
import 'package:budgcoach/features/budget/providers/budget_provider.dart';
import 'package:budgcoach/features/nudges/providers/nudges_provider.dart';
import 'package:budgcoach/features/savings/providers/savings_provider.dart';
import 'package:budgcoach/features/transactions/providers/transactions_provider.dart';
import 'package:budgcoach/shared/models/nudge_model.dart';
import 'package:budgcoach/shared/models/savings_goal_model.dart';
import 'package:budgcoach/shared/models/transaction_model.dart';
import 'package:budgcoach/shared/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late UserModel originalUser;
  late List<TransactionModel> originalTransactions;
  late List<SavingsGoalModel> originalGoals;
  late List<NudgeModel> originalNudges;

  setUp(() {
    originalUser = MockData.mockUser;
    originalTransactions = List.of(MockData.mockTransactions);
    originalGoals = List.of(MockData.mockSavingsGoals);
    originalNudges = List.of(MockData.mockNudges);
  });

  tearDown(() {
    MockData.mockUser = originalUser;
    MockData.mockTransactions = originalTransactions;
    MockData.mockSavingsGoals = originalGoals;
    MockData.mockNudges = originalNudges;
  });

  test(
    'auth notifier supports login, onboarding, profile update and logout',
    () {
      final notifier = AuthNotifier();

      notifier.login();
      expect(notifier.state.isLoggedIn, isTrue);

      notifier.completeOnboarding(
        name: 'Aryaman Bista',
        occupation: 'Student',
        monthlyIncome: 45000,
      );
      expect(notifier.state.isOnboardingCompleted, isTrue);
      expect(notifier.state.user?.monthlyIncome, 45000);

      notifier.updateMonthlyIncome(50000);
      expect(notifier.state.user?.monthlyIncome, 50000);

      notifier.toggleTheme();
      expect(notifier.state.themeMode, ThemeMode.dark);

      notifier.logout();
      expect(notifier.state.isLoggedIn, isFalse);
    },
  );

  test('transactions notifier sorts, adds, overrides and deletes', () {
    MockData.mockTransactions = [
      TransactionModel(
        id: 'old',
        description: 'Old',
        amount: -10,
        date: DateTime(2026, 8, 1),
        category: TransactionCategory.other,
        source: 'Manual',
      ),
      TransactionModel(
        id: 'new',
        description: 'New',
        amount: -20,
        date: DateTime(2026, 8, 2),
        category: TransactionCategory.food,
        source: 'eSewa',
      ),
    ];
    final notifier = TransactionsNotifier();
    expect(notifier.state.first.id, 'new');

    notifier.addTransaction(
      TransactionModel(
        id: 'latest',
        description: 'Latest',
        amount: -30,
        date: DateTime(2026, 8, 3),
        category: TransactionCategory.shopping,
        source: 'Khalti',
        confidence: 0.6,
      ),
    );
    expect(notifier.state.first.id, 'latest');

    notifier.overrideCategory('latest', TransactionCategory.education);
    final updated = notifier.state.firstWhere((tx) => tx.id == 'latest');
    expect(updated.category, TransactionCategory.education);
    expect(updated.confidence, 1.0);

    notifier.deleteTransaction('latest');
    expect(notifier.state.any((tx) => tx.id == 'latest'), isFalse);
  });

  test('savings notifier adds contributions and deletes goals', () {
    MockData.mockSavingsGoals = [
      SavingsGoalModel(
        id: 'goal-1',
        name: 'Emergency Fund',
        targetAmount: 50000,
        currentAmount: 10000,
        deadline: DateTime(2027, 12, 31),
        emoji: 'shield',
        monthlyContribution: 5000,
      ),
    ];
    final notifier = SavingsGoalsNotifier();

    notifier.addContribution('goal-1', 2500);
    expect(notifier.state.single.currentAmount, 12500);
    expect(notifier.state.single.contributionHistory.single.amount, 2500);

    notifier.deleteGoal('goal-1');
    expect(notifier.state, isEmpty);
  });

  test('nudge notifier records dismissal', () {
    MockData.mockNudges = [
      NudgeModel(
        id: 'nudge-1',
        title: 'Budget warning',
        description: 'Near the limit',
        severity: NudgeSeverity.warning,
        date: DateTime(2026, 8, 14),
      ),
    ];
    final notifier = NudgesNotifier();

    notifier.dismissNudge('nudge-1');
    expect(notifier.state.single.isDismissed, isTrue);
  });

  test('budget limit notifier updates a category limit immutably', () {
    final notifier = BudgetLimitsNotifier();
    final previousState = notifier.state;

    notifier.updateLimit(TransactionCategory.food, 9000);

    expect(notifier.state[TransactionCategory.food], 9000);
    expect(identical(previousState, notifier.state), isFalse);
  });
}
