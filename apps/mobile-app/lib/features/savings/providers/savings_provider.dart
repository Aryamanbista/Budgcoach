import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../shared/models/savings_goal_model.dart';
import '../../../core/network/api_client.dart';

class SavingsGoalsNotifier
    extends StateNotifier<AsyncValue<List<SavingsGoalModel>>> {
  final ApiClient _apiClient;

  SavingsGoalsNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    fetchGoals();
  }

  Future<void> fetchGoals() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.dio.get('/goals/');
      final data = response.data as List<dynamic>;
      final goals = data
          .map(
            (item) => SavingsGoalModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      state = AsyncValue.data(goals);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addGoal(SavingsGoalModel goal) async {
    try {
      await _apiClient.dio.post(
        '/goals/',
        data: {
          'name': goal.name,
          'target_amount': goal.targetAmount,
          'current_amount': goal.currentAmount,
          'deadline_date': goal.deadline.toIso8601String().split('T').first,
        },
      );
      await fetchGoals();
    } catch (e) {
      debugPrint('Error adding goal: $e');
    }
  }

  Future<void> addContribution(String goalId, double amount) async {
    try {
      final goals = state.asData?.value;
      if (goals == null) return;
      final goal = goals.firstWhere((item) => item.id == goalId);
      await _apiClient.dio.patch(
        '/goals/$goalId',
        data: {'current_amount': goal.currentAmount + amount},
      );
      await fetchGoals();
    } catch (e) {
      debugPrint('Error adding contribution: $e');
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      await _apiClient.dio.delete('/goals/$id');
      await fetchGoals();
    } catch (e) {
      debugPrint('Error deleting goal: $e');
    }
  }
}

final savingsGoalsProvider =
    StateNotifierProvider<
      SavingsGoalsNotifier,
      AsyncValue<List<SavingsGoalModel>>
    >((ref) {
      return SavingsGoalsNotifier(ref.watch(apiClientProvider));
    });
