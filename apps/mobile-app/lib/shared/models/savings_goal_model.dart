class SavingsContribution {
  final DateTime date;
  final double amount;

  SavingsContribution({required this.date, required this.amount});

  factory SavingsContribution.fromJson(Map<String, dynamic> json) {
    return SavingsContribution(
      date: DateTime.parse(json['date'].toString()),
      amount: double.parse(json['amount'].toString()),
    );
  }
}

class SavingsGoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;
  final String emoji;
  final double monthlyContribution;
  final List<SavingsContribution> contributionHistory;

  SavingsGoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.emoji,
    required this.monthlyContribution,
    this.contributionHistory = const [],
  });

  factory SavingsGoalModel.fromJson(Map<String, dynamic> json) {
    final deadline = DateTime.parse(json['deadline_date'].toString());
    final target = double.parse(json['target_amount'].toString());
    final current = double.parse(json['current_amount'].toString());
    final daysRemaining = deadline.difference(DateTime.now()).inDays;
    final monthsRemaining = (daysRemaining / 30).clamp(1, 120);

    return SavingsGoalModel(
      id: json['id'].toString(),
      name: json['name'].toString(),
      targetAmount: target,
      currentAmount: current,
      deadline: deadline,
      emoji: json['emoji']?.toString() ?? '🎯',
      monthlyContribution:
          ((target - current).clamp(0, double.infinity)) / monthsRemaining,
      contributionHistory:
          (json['contribution_history'] as List<dynamic>?)
              ?.map(
                (item) =>
                    SavingsContribution.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  double get progressPercentage =>
      targetAmount > 0 ? (currentAmount / targetAmount) : 0.0;
  double get remainingAmount => targetAmount - currentAmount;
  bool get isCompleted => currentAmount >= targetAmount;

  SavingsGoalModel copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? emoji,
    double? monthlyContribution,
    List<SavingsContribution>? contributionHistory,
  }) {
    return SavingsGoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      emoji: emoji ?? this.emoji,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      contributionHistory: contributionHistory ?? this.contributionHistory,
    );
  }
}
