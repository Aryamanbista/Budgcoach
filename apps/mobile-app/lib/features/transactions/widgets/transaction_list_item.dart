import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/category_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/transaction_model.dart';

class TransactionListItem extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = transaction.category.color;
    final isExpense = transaction.amount < 0;
    final amountColor = isExpense ? AppColors.danger : AppColors.success;

    // Formatting time: eSewa statements might have dates or specific times. E.g. "2:30 PM"
    final timeStr = DateFormat('h:mm a').format(transaction.date);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: catColor.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          transaction.category.emoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
      title: Text(
        transaction.description,
        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${transaction.category.displayName} · $timeStr',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Text(
        Formatters.formatNpr(transaction.amount, showSign: true),
        style: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
    );
  }
}
