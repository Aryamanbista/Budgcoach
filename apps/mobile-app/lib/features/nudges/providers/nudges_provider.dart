import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/nudge_model.dart';
import '../../../core/network/api_client.dart';

class NudgesNotifier extends StateNotifier<List<NudgeModel>> {
  final ApiClient _apiClient;

  NudgesNotifier(this._apiClient) : super([]) {
    fetchNudges();
  }

  Future<void> fetchNudges() async {
    try {
      final response = await _apiClient.dio.get('/nudges/');
      final data = response.data as List<dynamic>;
      state = data.map((e) => NudgeModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Failed to fetch nudges: $e');
    }
  }

  void dismissNudge(String id) {
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(isDismissed: true);
      }
      return n;
    }).toList();
  }
}

final nudgesProvider = StateNotifierProvider<NudgesNotifier, List<NudgeModel>>((
  ref,
) {
  return NudgesNotifier(ref.watch(apiClientProvider));
});
