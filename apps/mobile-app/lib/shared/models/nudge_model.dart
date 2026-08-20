import '../../core/constants/category_constants.dart';

enum NudgeSeverity { info, success, warning, critical }

class NudgeModel {
  final String id;
  final String title;
  final String description;
  final NudgeSeverity severity;
  final DateTime date;
  final DateTime expiresAt;
  final TransactionCategory? category;
  final String? actionLabel;
  final String? actionRoute;
  final int priority;
  final Map<String, dynamic> metrics;
  final bool isDismissed;

  NudgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.date,
    DateTime? expiresAt,
    this.priority = 0,
    this.metrics = const <String, dynamic>{},
    this.category,
    this.actionLabel,
    this.actionRoute,
    this.isDismissed = false,
  }) : expiresAt = expiresAt ?? date.add(const Duration(days: 1));

  NudgeModel copyWith({bool? isDismissed}) {
    return NudgeModel(
      id: id,
      title: title,
      description: description,
      severity: severity,
      date: date,
      expiresAt: expiresAt,
      category: category,
      actionLabel: actionLabel,
      actionRoute: actionRoute,
      priority: priority,
      metrics: metrics,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  factory NudgeModel.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category']?.toString();
    return NudgeModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notice',
      description: json['message']?.toString() ?? '',
      severity: _severityFromString(json['type']?.toString() ?? 'info'),
      date:
          DateTime.tryParse(
            json['generated_at']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expires_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      category: rawCategory == null
          ? null
          : CategoryConstants.fromString(rawCategory),
      actionLabel: json['action_label']?.toString(),
      actionRoute: json['action_route']?.toString(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      metrics:
          (json['metric_data'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      isDismissed: json['is_dismissed'] == true || json['dismissed_at'] != null,
    );
  }

  static NudgeSeverity _severityFromString(String value) {
    switch (value) {
      case 'critical':
        return NudgeSeverity.critical;
      case 'warning':
      case 'alert':
        return NudgeSeverity.warning;
      case 'success':
        return NudgeSeverity.success;
      default:
        return NudgeSeverity.info;
    }
  }
}
