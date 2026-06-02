import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/nudge_model.dart';
import '../../../core/mock/mock_data.dart';

class NudgesNotifier extends StateNotifier<List<NudgeModel>> {
  NudgesNotifier() : super(List.from(MockData.mockNudges));

  void dismissNudge(String id) {
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(isDismissed: true);
      }
      return n;
    }).toList();
    MockData.mockNudges = state;
  }
}

final nudgesProvider = StateNotifierProvider<NudgesNotifier, List<NudgeModel>>((ref) {
  return NudgesNotifier();
});
