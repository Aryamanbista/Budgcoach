import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/category_constants.dart';
import '../../../../core/utils/formatters.dart';

class CategoryChipItem {
  final TransactionCategory category;
  final double amount;

  CategoryChipItem({required this.category, required this.amount});
}

class CategoryChipsRow extends StatelessWidget {
  final List<CategoryChipItem> items;

  const CategoryChipsRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final color = item.category.color;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                Text(item.category.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.category.displayName,
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      Formatters.formatNpr(item.amount),
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
