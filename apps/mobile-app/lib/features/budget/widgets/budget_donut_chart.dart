import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/category_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/models/budget_model.dart';

class BudgetDonutChart extends StatelessWidget {
  final List<BudgetModel> budgets;

  const BudgetDonutChart({super.key, required this.budgets});

  @override
  Widget build(BuildContext context) {
    // Calculate total budget & spent (exclude Income and Transfer)
    final activeBudgets = budgets
        .where(
          (b) =>
              b.category != TransactionCategory.income &&
              b.category != TransactionCategory.transfer &&
              b.category != TransactionCategory.savings &&
              b.spent > 0,
        )
        .toList();

    final totalSpent = activeBudgets.fold(0.0, (sum, b) => sum + b.spent);
    final totalBudget = budgets
        .where(
          (b) =>
              b.category != TransactionCategory.income &&
              b.category != TransactionCategory.transfer &&
              b.category != TransactionCategory.savings,
        )
        .fold(0.0, (sum, b) => sum + b.limit);

    // If no spending has occurred, show a placeholder segment
    final List<PieChartSectionData> sections = activeBudgets.isEmpty
        ? [
            PieChartSectionData(
              color: Colors.grey[300]!,
              value: 100,
              title: '',
              radius: 20,
            ),
          ]
        : activeBudgets.map((b) {
            return PieChartSectionData(
              color: b.category.color,
              value: b.spent,
              title: '', // Empty since legend is shown on details card list
              radius: 20,
            );
          }).toList();

    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 65,
              sections: sections,
              startDegreeOffset: 270,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Spent',
                style: AppTextStyles.labelSmall.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                Formatters.formatNpr(totalSpent),
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'of ${Formatters.formatNpr(totalBudget)}',
                style: AppTextStyles.labelSmall.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
