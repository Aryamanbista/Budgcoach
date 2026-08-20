import 'package:budgcoach/core/constants/category_constants.dart';
import 'package:budgcoach/features/auth/providers/auth_provider.dart';
import 'package:budgcoach/shared/models/budget_model.dart';
import 'package:budgcoach/shared/models/savings_goal_model.dart';
import 'package:budgcoach/shared/models/transaction_model.dart';
import 'package:budgcoach/shared/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth state can clear sensitive user data on logout', () {
    final state = AuthState(
      isLoggedIn: true,
      isOnboardingCompleted: true,
      user: UserModel(
        id: 'user-1',
        name: 'Test User',
        email: 'test@example.com',
        occupation: 'Student',
        monthlyIncome: 45000,
      ),
      themeMode: ThemeMode.light,
    );

    final loggedOut = state.copyWith(
      isLoggedIn: false,
      isOnboardingCompleted: false,
      clearUser: true,
    );

    expect(loggedOut.isLoggedIn, isFalse);
    expect(loggedOut.user, isNull);
  });

  test('transaction JSON preserves debit and credit direction', () {
    final debit = TransactionModel.fromJson({
      'id': 'debit-1',
      'amount': '1250.50',
      'type': 'debit',
      'date': '2026-08-20',
      'clean_text': 'Grocery purchase',
    });
    final credit = TransactionModel.fromJson({
      'id': 'credit-1',
      'amount': '5000',
      'type': 'credit',
      'date': '2026-08-21',
      'clean_text': 'Salary',
    });

    expect(debit.amount, -1250.50);
    expect(debit.isExpense, isTrue);
    expect(credit.amount, 5000);
    expect(credit.isIncome, isTrue);
  });

  test('savings goal parses the FastAPI response contract', () {
    final goal = SavingsGoalModel.fromJson({
      'id': 'goal-1',
      'name': 'Emergency Fund',
      'target_amount': '100000.00',
      'current_amount': '25000.00',
      'deadline_date': '2027-08-20',
    });

    expect(goal.id, 'goal-1');
    expect(goal.targetAmount, 100000);
    expect(goal.currentAmount, 25000);
    expect(goal.remainingAmount, 75000);
    expect(goal.monthlyContribution, greaterThan(0));
  });

  test('budget model calculates progress and remaining amount', () {
    final budget = BudgetModel(
      category: TransactionCategory.food,
      limit: 10000,
      spent: 6500,
    );

    expect(budget.remaining, 3500);
    expect(budget.percentageSpent, 0.65);
    expect(budget.isOverBudget, isFalse);
  });

  test('category parser accepts API and display labels', () {
    expect(CategoryConstants.fromString('food'), TransactionCategory.food);
    expect(
      CategoryConstants.fromString('Food & Dining'),
      TransactionCategory.food,
    );
    expect(TransactionCategory.food.displayName, 'Food & Dining');
  });
}
