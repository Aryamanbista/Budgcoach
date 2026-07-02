import '../../core/constants/category_constants.dart';

class BudgetModel {
  final TransactionCategory category;
  final double limit;
  final double spent;

  BudgetModel({
    required this.category,
    required this.limit,
    required this.spent,
  });

  double get remaining => limit - spent;
  double get percentageSpent => limit > 0 ? (spent / limit) : 0.0;
  bool get isOverBudget => spent > limit;

  BudgetModel copyWith({
    TransactionCategory? category,
    double? limit,
    double? spent,
  }) {
    return BudgetModel(
      category: category ?? this.category,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
    );
  }
}
