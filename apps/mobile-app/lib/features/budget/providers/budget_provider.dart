import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/budget_model.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/constants/category_constants.dart';
import '../../transactions/providers/transactions_provider.dart';

class BudgetLimitsNotifier extends StateNotifier<Map<TransactionCategory, double>> {
  BudgetLimitsNotifier()
      : super({
          for (var b in MockData.mockBudgets) b.category: b.limit
        });

  void updateLimit(TransactionCategory category, double limit) {
    state = {...state, category: limit};
  }
  
  void setLimits(Map<TransactionCategory, double> newLimits) {
    state = newLimits;
  }
}

final budgetLimitsProvider = StateNotifierProvider<BudgetLimitsNotifier, Map<TransactionCategory, double>>((ref) {
  return BudgetLimitsNotifier();
});

final budgetsProvider = Provider<List<BudgetModel>>((ref) {
  final limits = ref.watch(budgetLimitsProvider);
  final transactions = ref.watch(transactionsProvider);
  
  final now = DateTime.now();
  
  return TransactionCategory.values.map((category) {
    // Sum only negative amounts (expenses) for this category in the current month
    final spent = transactions
        .where((tx) =>
            tx.category == category &&
            tx.amount < 0 &&
            tx.date.month == now.month &&
            tx.date.year == now.year)
        .fold(0.0, (sum, tx) => sum + tx.amount.abs());
        
    return BudgetModel(
      category: category,
      limit: limits[category] ?? 0.0,
      spent: spent,
    );
  }).toList();
});
