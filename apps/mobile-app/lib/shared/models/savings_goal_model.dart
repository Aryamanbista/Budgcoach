class SavingsContribution {
  final DateTime date;
  final double amount;

  SavingsContribution({
    required this.date,
    required this.amount,
  });
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

  double get progressPercentage => targetAmount > 0 ? (currentAmount / targetAmount) : 0.0;
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
