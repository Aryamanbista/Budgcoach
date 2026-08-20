import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/category_constants.dart';
import '../providers/budget_provider.dart';
import '../widgets/budget_donut_chart.dart';
import '../widgets/category_budget_card.dart';
import '../widgets/set_budget_sheet.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);

    // Filter budgets to display spending categories (exclude Income and Transfer)
    final displayBudgets = budgets
        .where(
          (b) =>
              b.category != TransactionCategory.income &&
              b.category != TransactionCategory.transfer,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Month Navigator (← June 2026 →)
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            color: Theme.of(context).cardTheme.color,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {},
                ),
                Text(
                  'June 2026',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Donut Chart Card
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Spending Allocation breakdown',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          BudgetDonutChart(budgets: budgets),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Budgets Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Category Budgets',
                        style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
                      ),
                    ),
                  ),

                  // Budgets progress list
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayBudgets.length,
                    itemBuilder: (context, index) {
                      final budget = displayBudgets[index];
                      return CategoryBudgetCard(budget: budget);
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => const SetBudgetSheet(),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit),
      ),
    );
  }
}
