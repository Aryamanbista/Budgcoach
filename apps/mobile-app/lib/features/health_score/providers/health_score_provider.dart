import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'package:flutter/foundation.dart';

class HealthScoreData {
  final int score;
  final Map<String, int> subScores;

  HealthScoreData({required this.score, required this.subScores});
}

class HealthScoreNotifier extends StateNotifier<AsyncValue<HealthScoreData>> {
  final ApiClient _apiClient;

  HealthScoreNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    fetchScore();
  }

  Future<void> fetchScore() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.dio.get('/health-score/');
      final data = response.data;

      final subScores = {
        'Savings Rate': (data['details']['savings_rate_score'] as num).toInt(),
        'Budget Adherence': (data['details']['budget_adherence_score'] as num)
            .toInt(),
        'Goal Progress': (data['details']['goal_progress_score'] as num)
            .toInt(),
      };

      state = AsyncValue.data(
        HealthScoreData(
          score: (data['health_score'] as num).toInt(),
          subScores: subScores,
        ),
      );
    } catch (e, st) {
      debugPrint('Failed to fetch health score: $e');
      state = AsyncValue.error(e, st);
    }
  }
}

final healthScoreProvider =
    StateNotifierProvider<HealthScoreNotifier, AsyncValue<HealthScoreData>>((
      ref,
    ) {
      return HealthScoreNotifier(ref.watch(apiClientProvider));
    });
