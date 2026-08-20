import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/nudge_model.dart';

class NudgesNotifier extends StateNotifier<AsyncValue<List<NudgeModel>>> {
  final ApiClient _apiClient;

  NudgesNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    fetchNudges();
  }

  Future<void> fetchNudges() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.dio.get('/nudges/');
      final data = response.data as List<dynamic>;
      state = AsyncValue.data(
        data
            .map((item) => NudgeModel.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch nudges: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> dismissNudge(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current
          .map(
            (nudge) =>
                nudge.id == id ? nudge.copyWith(isDismissed: true) : nudge,
          )
          .toList(),
    );

    try {
      await _apiClient.dio.patch('/nudges/$id/dismiss');
    } catch (error) {
      debugPrint('Failed to dismiss nudge: $error');
      state = AsyncValue.data(current);
    }
  }
}

final nudgesProvider =
    StateNotifierProvider<NudgesNotifier, AsyncValue<List<NudgeModel>>>(
      (ref) => NudgesNotifier(ref.watch(apiClientProvider)),
    );
