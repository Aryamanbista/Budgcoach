import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'package:flutter/foundation.dart';

class ForecastData {
  final Map<int, double> actualPoints;
  final Map<int, double> predictedPoints;

  ForecastData({required this.actualPoints, required this.predictedPoints});
}

class ForecastNotifier extends StateNotifier<AsyncValue<ForecastData>> {
  final ApiClient _apiClient;

  ForecastNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    fetchForecast();
  }

  Future<void> fetchForecast() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.dio.get('/forecast/');
      final data = response.data;

      final Map<int, double> actual = {};
      final Map<int, double> predicted = {};

      // Parse actual points
      final historyList = data['history_used'] as List;
      for (int i = 0; i < historyList.length; i++) {
        actual[i] = double.parse(historyList[i]['amount'].toString());
      }

      // Parse predicted points
      final forecastList = data['forecast'] as List;
      int startIdx = historyList.length;

      // Add the last actual point to predicted to connect the line visually
      if (historyList.isNotEmpty) {
        predicted[startIdx - 1] = double.parse(
          historyList.last['amount'].toString(),
        );
      }

      for (int i = 0; i < forecastList.length; i++) {
        predicted[startIdx + i] = double.parse(
          forecastList[i]['amount'].toString(),
        );
      }

      state = AsyncValue.data(
        ForecastData(actualPoints: actual, predictedPoints: predicted),
      );
    } catch (e, st) {
      debugPrint('Failed to fetch forecast: $e');
      state = AsyncValue.error(e, st);
    }
  }
}

final forecastProvider =
    StateNotifierProvider<ForecastNotifier, AsyncValue<ForecastData>>((ref) {
      return ForecastNotifier(ref.watch(apiClientProvider));
    });
