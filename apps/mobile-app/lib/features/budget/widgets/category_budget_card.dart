import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/category_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/models/budget_model.dart';

class CategoryBudgetCard extends StatelessWidget {
  final BudgetModel budget;

  const CategoryBudgetCard({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final catColor = budget.category.color;
    final percentage = budget.percentageSpent;
    final isOver = budget.isOverBudget;

    // Choose status colors
    Color statusColor = AppColors.primary;
    if (percentage > 0.9) {
      statusColor = AppColors.danger;
    } else if (percentage >= 0.7) {
      statusColor = AppColors.secondary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Emoji and Category Label
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          budget.category.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              budget.category.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isOver) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Over budget!',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Spent vs Limit
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${Formatters.formatNpr(budget.spent)} / ${Formatters.formatNpr(budget.limit)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isOver
                              ? AppColors.danger
                              : Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      Text(
                        '${(percentage * 100).toInt()}% spent',
                        maxLines: 1,
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Theme.of(
                  context,
                ).dividerColor.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
