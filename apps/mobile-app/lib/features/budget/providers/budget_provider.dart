import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/budget_model.dart';
import '../../../core/constants/category_constants.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../../core/network/api_client.dart';
import 'package:intl/intl.dart';

class BudgetLimitsNotifier
    extends StateNotifier<Map<TransactionCategory, double>> {
  final ApiClient _apiClient;
  final Map<TransactionCategory, String> _categoryIds = {};
  final Map<TransactionCategory, String> _budgetIds = {};

  BudgetLimitsNotifier(this._apiClient) : super({}) {
    fetchBudgets();
  }

  Future<void> fetchBudgets() async {
    try {
      // 1. Fetch categories to build mapping (UUID -> Name -> Enum)
      final catResponse = await _apiClient.dio.get('/categories/');
      final catData = catResponse.data as List<dynamic>;
      final Map<String, TransactionCategory> uuidToEnum = {};

      for (var cat in catData) {
        final String id = cat['id'];
        final String name = cat['name'].toString().toLowerCase();

        // Find matching enum
        final enumMatch = TransactionCategory.values.firstWhere(
          (e) =>
              e.name.toLowerCase() == name ||
              e.displayName.toLowerCase() == name,
          orElse: () => TransactionCategory.other,
        );
        uuidToEnum[id] = enumMatch;
        _categoryIds[enumMatch] = id;
      }

      // 2. Fetch budgets
      final now = DateTime.now();
      final monthYear = DateFormat('MM-yyyy').format(now);

      final response = await _apiClient.dio.get(
        '/budgets/',
        queryParameters: {'month_year': monthYear},
      );
      final data = response.data as List<dynamic>;

      final Map<TransactionCategory, double> limits = {};
      for (var b in data) {
        final catId = b['category_id'];
        final limit = double.parse(b['limit_amount'].toString());
        final enumCat = uuidToEnum[catId];
        if (enumCat != null) {
          limits[enumCat] = limit;
          _budgetIds[enumCat] = b['id'].toString();
        }
      }

      state = limits;
    } catch (e) {
      debugPrint('Failed to fetch budgets: $e');
    }
  }

  void updateLimit(TransactionCategory category, double limit) {
    state = {...state, category: limit};
  }

  Future<void> setLimits(Map<TransactionCategory, double> newLimits) async {
    final previousState = state;
    state = Map.unmodifiable(newLimits);

    try {
      final monthYear = DateFormat('MM-yyyy').format(DateTime.now());
      for (final entry in newLimits.entries) {
        final categoryId = _categoryIds[entry.key];
        if (categoryId == null) continue;

        final budgetId = _budgetIds[entry.key];
        if (budgetId == null) {
          final response = await _apiClient.dio.post(
            '/budgets/',
            data: {
              'category_id': categoryId,
              'limit_amount': entry.value,
              'spent_amount': 0,
              'month_year': monthYear,
            },
          );
          _budgetIds[entry.key] = response.data['id'].toString();
        } else {
          await _apiClient.dio.patch(
            '/budgets/$budgetId',
            data: {'limit_amount': entry.value},
          );
        }
      }
    } catch (_) {
      state = previousState;
      rethrow;
    }
  }
}

final budgetLimitsProvider =
    StateNotifierProvider<
      BudgetLimitsNotifier,
      Map<TransactionCategory, double>
    >((ref) {
      return BudgetLimitsNotifier(ref.watch(apiClientProvider));
    });

final budgetsProvider = Provider<List<BudgetModel>>((ref) {
  final limits = ref.watch(budgetLimitsProvider);
  final transactions = ref.watch(transactionsProvider);

  final now = DateTime.now();

  return TransactionCategory.values.map((category) {
    // Sum only negative amounts (expenses) for this category in the current month
    final spent = transactions
        .where(
          (tx) =>
              tx.category == category &&
              tx.amount < 0 &&
              tx.date.month == now.month &&
              tx.date.year == now.year,
        )
        .fold(0.0, (sum, tx) => sum + tx.amount.abs());

    return BudgetModel(
      category: category,
      limit: limits[category] ?? 0.0,
      spent: spent,
    );
  }).toList();
});
