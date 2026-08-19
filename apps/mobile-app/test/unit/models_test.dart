import 'package:budgcoach/core/constants/category_constants.dart';
import 'package:budgcoach/shared/models/budget_model.dart';
import 'package:budgcoach/shared/models/savings_goal_model.dart';
import 'package:budgcoach/shared/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BudgetModel', () {
    test('calculates remaining amount and utilization', () {
      final budget = BudgetModel(
        category: TransactionCategory.food,
        limit: 8000,
        spent: 5200,
      );

      expect(budget.remaining, 2800);
      expect(budget.percentageSpent, closeTo(0.65, 0.0001));
      expect(budget.isOverBudget, isFalse);
    });

    test('detects over-budget and protects division by zero', () {
      final exceeded = BudgetModel(
        category: TransactionCategory.shopping,
        limit: 4000,
        spent: 4300,
      );
      final zero = BudgetModel(
        category: TransactionCategory.other,
        limit: 0,
        spent: 100,
      );

      expect(exceeded.isOverBudget, isTrue);
      expect(zero.percentageSpent, 0);
    });
  });

  group('SavingsGoalModel', () {
    test('calculates progress, remaining amount and completion', () {
      final goal = SavingsGoalModel(
        id: 'goal-1',
        name: 'Emergency Fund',
        targetAmount: 50000,
        currentAmount: 15000,
        deadline: DateTime(2027, 12, 31),
        emoji: 'shield',
        monthlyContribution: 5000,
      );

      expect(goal.progressPercentage, 0.3);
      expect(goal.remainingAmount, 35000);
      expect(goal.isCompleted, isFalse);
      expect(goal.copyWith(currentAmount: 50000).isCompleted, isTrue);
    });
  });

  group('TransactionModel and categories', () {
    test('identifies income and expenses', () {
      final expense = TransactionModel(
        id: 'tx-1',
        description: 'Momo',
        amount: -250,
        date: DateTime(2026, 8, 14),
        category: TransactionCategory.food,
        source: 'eSewa',
      );

      expect(expense.isExpense, isTrue);
      expect(expense.isIncome, isFalse);
      expect(expense.copyWith(amount: 500).isIncome, isTrue);
    });

    test('maps display and enum names with safe fallback', () {
      expect(
        CategoryConstants.fromString('Food & Dining'),
        TransactionCategory.food,
      );
      expect(
        CategoryConstants.fromString('transport'),
        TransactionCategory.transport,
      );
      expect(
        CategoryConstants.fromString('unknown'),
        TransactionCategory.other,
      );
    });
  });
}
