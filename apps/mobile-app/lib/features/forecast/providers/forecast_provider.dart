import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class ForecastAiStatus {
  final int daysLogged;
  final int requiredDays;
  final double readinessPercentage;
  final String activeModel;
  final String learningMessage;
  final String coverageStatus;
  final bool isFresh;
  final int modelDaysLogged;
  final int modelRequiredDays;
  final double? validationMae;
  final bool selectedViaBacktest;

  const ForecastAiStatus({
    required this.daysLogged,
    required this.requiredDays,
    required this.readinessPercentage,
    required this.activeModel,
    required this.learningMessage,
    required this.coverageStatus,
    required this.isFresh,
    required this.modelDaysLogged,
    required this.modelRequiredDays,
    required this.validationMae,
    required this.selectedViaBacktest,
  });

  factory ForecastAiStatus.fromJson(Map<String, dynamic> json) {
    return ForecastAiStatus(
      daysLogged: (json['days_logged'] as num?)?.toInt() ?? 0,
      requiredDays: (json['required_days'] as num?)?.toInt() ?? 30,
      readinessPercentage:
          (json['readiness_percentage'] as num?)?.toDouble() ?? 0,
      activeModel: json['active_model']?.toString() ?? 'personal_baseline',
      learningMessage:
          json['learning_message']?.toString() ??
          'Budgcoach is learning your spending rhythm.',
      coverageStatus: json['coverage_status']?.toString() ?? 'estimated',
      isFresh: json['is_fresh'] == true,
      modelDaysLogged: (json['training_days_logged'] as num?)?.toInt() ?? 0,
      modelRequiredDays:
          (json['training_required_days'] as num?)?.toInt() ?? 180,
      validationMae: (json['validation_mae'] as num?)?.toDouble(),
      selectedViaBacktest: json['selected_via_backtest'] == true,
    );
  }

  bool get isLearning => activeModel != 'lstm_network';

  double get modelReadiness => modelRequiredDays <= 0
      ? 0
      : (modelDaysLogged / modelRequiredDays).clamp(0.0, 1.0);

  String get coverageLabel {
    switch (coverageStatus) {
      case 'verified':
        return isFresh ? 'Verified & current' : 'Verified · update needed';
      case 'none':
        return 'No history yet';
      default:
        return 'Estimated coverage';
    }
  }

  String get modelLabel {
    switch (activeModel) {
      case 'lstm_network':
        return 'Personal AI';
      case 'arima_baseline':
        return 'ARIMA baseline';
      default:
        return 'Personal baseline';
    }
  }
}

class ForecastFestival {
  final DateTime date;
  final String name;
  final bool isMajor;

  const ForecastFestival({
    required this.date,
    required this.name,
    required this.isMajor,
  });

  factory ForecastFestival.fromJson(Map<String, dynamic> json) {
    return ForecastFestival(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      name: json['name']?.toString() ?? 'Festival',
      isMajor: json['is_major'] == true,
    );
  }
}

class ForecastData {
  final Map<int, double> actualPoints;
  final Map<int, double> predictedPoints;
  final double predictedSpend;
  final double currentMonthSpend;
  final double totalBudget;
  final double remainingBudget;
  final bool budgetBreachWarning;
  final int daysUntilBreach;
  final ForecastAiStatus aiStatus;
  final List<ForecastFestival> upcomingFestivals;

  const ForecastData({
    required this.actualPoints,
    required this.predictedPoints,
    required this.predictedSpend,
    required this.currentMonthSpend,
    required this.totalBudget,
    required this.remainingBudget,
    required this.budgetBreachWarning,
    required this.daysUntilBreach,
    required this.aiStatus,
    required this.upcomingFestivals,
  });

  factory ForecastData.fromJson(Map<String, dynamic> json) {
    final history = (json['history_used'] as List<dynamic>? ?? const []);
    final forecast = (json['forecast'] as List<dynamic>? ?? const []);

    final actualPoints = <int, double>{};
    for (final item in history) {
      final point = item as Map<String, dynamic>;
      final parsedDate = DateTime.tryParse(point['date']?.toString() ?? '');
      if (parsedDate != null) {
        actualPoints[parsedDate.day] =
            (point['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final predictedPoints = <int, double>{};
    if (history.isNotEmpty) {
      final last = history.last as Map<String, dynamic>;
      final date = DateTime.tryParse(last['date']?.toString() ?? '');
      if (date != null) {
        predictedPoints[date.day] = (last['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    for (final item in forecast) {
      final point = item as Map<String, dynamic>;
      final parsedDate = DateTime.tryParse(point['date']?.toString() ?? '');
      if (parsedDate != null) {
        predictedPoints[parsedDate.day] =
            (point['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    return ForecastData(
      actualPoints: actualPoints,
      predictedPoints: predictedPoints,
      predictedSpend: (json['predicted_spend'] as num?)?.toDouble() ?? 0,
      currentMonthSpend: (json['current_month_spend'] as num?)?.toDouble() ?? 0,
      totalBudget: (json['total_budget'] as num?)?.toDouble() ?? 0,
      remainingBudget: (json['remaining_budget'] as num?)?.toDouble() ?? 0,
      budgetBreachWarning: json['budget_breach_warning'] == true,
      daysUntilBreach: (json['days_until_breach'] as num?)?.toInt() ?? 0,
      aiStatus: ForecastAiStatus.fromJson(
        json['ai_status'] as Map<String, dynamic>? ?? const {},
      ),
      upcomingFestivals:
          (json['upcoming_festivals'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    ForecastFestival.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
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
      state = AsyncValue.data(
        ForecastData.fromJson(response.data as Map<String, dynamic>),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch forecast: $error');
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final forecastProvider =
    StateNotifierProvider<ForecastNotifier, AsyncValue<ForecastData>>((ref) {
      return ForecastNotifier(ref.watch(apiClientProvider));
    });
