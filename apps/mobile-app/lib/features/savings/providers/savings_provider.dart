import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/savings_goal_model.dart';
import '../../../core/mock/mock_data.dart';

class SavingsGoalsNotifier extends StateNotifier<List<SavingsGoalModel>> {
  SavingsGoalsNotifier() : super(List.from(MockData.mockSavingsGoals));

  void addGoal(SavingsGoalModel goal) {
    state = [...state, goal];
    MockData.mockSavingsGoals = state;
  }

  void addContribution(String goalId, double amount) {
    state = state.map((g) {
      if (g.id == goalId) {
        final updatedHistory = [
          SavingsContribution(date: DateTime.now(), amount: amount),
          ...g.contributionHistory,
        ];
        return g.copyWith(
          currentAmount: g.currentAmount + amount,
          contributionHistory: updatedHistory,
        );
      }
      return g;
    }).toList();
    MockData.mockSavingsGoals = state;
  }

  void deleteGoal(String id) {
    state = state.where((g) => g.id != id).toList();
    MockData.mockSavingsGoals = state;
  }
}

final savingsGoalsProvider = StateNotifierProvider<SavingsGoalsNotifier, List<SavingsGoalModel>>((ref) {
  return SavingsGoalsNotifier();
});
