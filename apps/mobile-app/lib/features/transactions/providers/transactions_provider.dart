import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/transaction_model.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/constants/category_constants.dart';

class TransactionsNotifier extends StateNotifier<List<TransactionModel>> {
  TransactionsNotifier() : super(List.from(MockData.mockTransactions)) {
    _sortTransactions();
  }

  void _sortTransactions() {
    state.sort((a, b) => b.date.compareTo(a.date));
  }

  void addTransaction(TransactionModel transaction) {
    state = [transaction, ...state];
    _sortTransactions();
    MockData.mockTransactions = state; // Sync to global mock store
  }

  void deleteTransaction(String id) {
    state = state.where((tx) => tx.id != id).toList();
    MockData.mockTransactions = state;
  }

  void overrideCategory(String txId, TransactionCategory newCategory) {
    state = state.map((tx) {
      if (tx.id == txId) {
        return tx.copyWith(category: newCategory, confidence: 1.0);
      }
      return tx;
    }).toList();
    MockData.mockTransactions = state;
  }
}

final transactionsProvider = StateNotifierProvider<TransactionsNotifier, List<TransactionModel>>((ref) {
  return TransactionsNotifier();
});
