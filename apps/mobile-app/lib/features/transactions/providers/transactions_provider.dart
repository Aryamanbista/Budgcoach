import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/transaction_model.dart';
import '../../../core/constants/category_constants.dart';
import '../../../core/network/api_client.dart';

class TransactionsNotifier extends StateNotifier<List<TransactionModel>> {
  final ApiClient apiClient;

  TransactionsNotifier(this.apiClient) : super([]) {
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    try {
      final response = await apiClient.dio.get('/transactions');
      final data = response.data as List<dynamic>;
      state = data.map((json) => TransactionModel.fromJson(json)).toList();
      _sortTransactions();
    } catch (e) {
      debugPrint('Failed to fetch transactions: $e');
    }
  }

  void _sortTransactions() {
    state.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveParsedTransactions(List<TransactionModel> txs) async {
    try {
      final accountId = await _resolveDefaultAccountId();
      final payload = txs
          .map(
            (tx) => {
              'account_id': accountId,
              'amount': tx.amount.abs(),
              'type': tx.amount < 0 ? 'debit' : 'credit',
              'date': tx.date.toIso8601String(),
              'transaction_date': tx.date.toIso8601String(),
              'raw_text': tx.description,
              'clean_text': tx.description,
              'transaction_text': tx.description,
              'is_manual_entry': false,
              'ml_confidence_score': tx.confidence ?? 1.0,
            },
          )
          .toList();

      await apiClient.dio.post('/transactions/batch', data: payload);

      // Update local state anyway for immediate feedback
      state = [...txs, ...state];
      _sortTransactions();
    } catch (e) {
      debugPrint('Failed to batch save transactions: $e');
    }
  }

  Future<String> _resolveDefaultAccountId() async {
    final response = await apiClient.dio.get('/accounts/');
    final accounts = response.data as List<dynamic>;
    if (accounts.isNotEmpty) {
      return accounts.first['id'].toString();
    }

    final created = await apiClient.dio.post(
      '/accounts/',
      data: {'wallet_name': 'Default Wallet', 'balance': 0},
    );
    return created.data['id'].toString();
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    state = [transaction, ...state];
    _sortTransactions();
  }

  void deleteTransaction(String id) {
    state = state.where((tx) => tx.id != id).toList();
  }

  void overrideCategory(String txId, TransactionCategory newCategory) {
    state = state.map((tx) {
      if (tx.id == txId) {
        return tx.copyWith(category: newCategory, confidence: 1.0);
      }
      return tx;
    }).toList();
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, List<TransactionModel>>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      return TransactionsNotifier(apiClient);
    });
