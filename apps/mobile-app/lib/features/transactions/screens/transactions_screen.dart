import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/category_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/transaction_list_item.dart';
import 'add_transaction_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _searchQuery = '';
  TransactionFilters _filters = TransactionFilters.defaultFilters();

  Map<String, List<TransactionModel>> _groupTransactions(
    List<TransactionModel> txs,
  ) {
    final Map<String, List<TransactionModel>> groups = {};
    for (var tx in txs) {
      final key = Formatters.formatDateToWord(tx.date);
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(tx);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final allTxs = ref.watch(transactionsProvider);

    // Apply search and filter logic
    final now = DateTime.now();
    final filteredTxs = allTxs.where((tx) {
      // Search filter
      final matchesSearch =
          tx.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.category.displayName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      if (!matchesSearch) return false;

      // Category filter
      if (_filters.selectedCategories.isNotEmpty &&
          !_filters.selectedCategories.contains(tx.category)) {
        return false;
      }

      // Date range filter
      if (_filters.dateRange == 'This Month') {
        return tx.date.month == now.month && tx.date.year == now.year;
      } else if (_filters.dateRange == 'Last Month') {
        final lastMonth = now.month == 1 ? 12 : now.month - 1;
        final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
        return tx.date.month == lastMonth && tx.date.year == lastMonthYear;
      }

      return true;
    }).toList();

    // Apply sort logic
    if (_filters.sortBy == 'Newest') {
      filteredTxs.sort((a, b) => b.date.compareTo(a.date));
    } else if (_filters.sortBy == 'Oldest') {
      filteredTxs.sort((a, b) => a.date.compareTo(b.date));
    } else if (_filters.sortBy == 'Highest') {
      filteredTxs.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    } else if (_filters.sortBy == 'Lowest') {
      filteredTxs.sort((a, b) => a.amount.abs().compareTo(b.amount.abs()));
    }

    final groupedTxs = _groupTransactions(filteredTxs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible:
                  _filters.selectedCategories.isNotEmpty ||
                  _filters.dateRange != 'All',
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => FilterBottomSheet(
                  initialFilters: _filters,
                  onApply: (newFilters) {
                    setState(() {
                      _filters = newFilters;
                    });
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search description or category...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardTheme.color,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Transaction List Grouped By Date
          Expanded(
            child: filteredTxs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🔍', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: AppTextStyles.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try modifying your search or filter settings.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: groupedTxs.keys.length,
                    itemBuilder: (context, index) {
                      final groupKey = groupedTxs.keys.elementAt(index);
                      final groupTxs = groupedTxs[groupKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group Header (TODAY, YESTERDAY, date)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16.0,
                              top: 16.0,
                              bottom: 8.0,
                            ),
                            child: Text(
                              groupKey,
                              style: AppTextStyles.labelSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          // Group List Card
                          Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: groupTxs.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, indent: 80),
                              itemBuilder: (context, itemIndex) {
                                final tx = groupTxs[itemIndex];
                                return TransactionListItem(
                                  transaction: tx,
                                  onTap: () =>
                                      context.push('/transaction/${tx.id}'),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => const AddTransactionSheet(),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
