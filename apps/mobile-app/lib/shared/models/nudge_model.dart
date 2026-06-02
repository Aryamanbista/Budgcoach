import '../../core/constants/category_constants.dart';

enum NudgeSeverity {
  info,
  warning,
  critical,
}

class NudgeModel {
  final String id;
  final String title;
  final String description;
  final NudgeSeverity severity;
  final DateTime date;
  final TransactionCategory? category;
  final bool isDismissed;

  NudgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.date,
    this.category,
    this.isDismissed = false,
  });

  NudgeModel copyWith({
    String? id,
    String? title,
    String? description,
    NudgeSeverity? severity,
    DateTime? date,
    TransactionCategory? category,
    bool? isDismissed,
  }) {
    return NudgeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      date: date ?? this.date,
      category: category ?? this.category,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}
