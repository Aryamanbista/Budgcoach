import 'package:flutter/material.dart';
import 'app_colors.dart';

enum TransactionCategory {
  food,
  transport,
  utilities,
  entertainment,
  shopping,
  health,
  education,
  savings,
  income,
  festival,
  transfer,
  other,
}

extension TransactionCategoryExtension on TransactionCategory {
  String get name {
    switch (this) {
      case TransactionCategory.food:
        return 'Food & Dining';
      case TransactionCategory.transport:
        return 'Transport';
      case TransactionCategory.utilities:
        return 'Utilities';
      case TransactionCategory.entertainment:
        return 'Entertainment';
      case TransactionCategory.shopping:
        return 'Shopping';
      case TransactionCategory.health:
        return 'Health';
      case TransactionCategory.education:
        return 'Education';
      case TransactionCategory.savings:
        return 'Savings';
      case TransactionCategory.income:
        return 'Income';
      case TransactionCategory.festival:
        return 'Festival';
      case TransactionCategory.transfer:
        return 'Transfer';
      case TransactionCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case TransactionCategory.food:
        return '🍜';
      case TransactionCategory.transport:
        return '🚌';
      case TransactionCategory.utilities:
        return '💡';
      case TransactionCategory.entertainment:
        return '🎬';
      case TransactionCategory.shopping:
        return '🛍️';
      case TransactionCategory.health:
        return '🏥';
      case TransactionCategory.education:
        return '📚';
      case TransactionCategory.savings:
        return '💰';
      case TransactionCategory.income:
        return '💵';
      case TransactionCategory.festival:
        return '🎉';
      case TransactionCategory.transfer:
        return '🔄';
      case TransactionCategory.other:
        return '📦';
    }
  }

  Color get color {
    switch (this) {
      case TransactionCategory.food:
        return AppColors.catFood;
      case TransactionCategory.transport:
        return AppColors.catTransport;
      case TransactionCategory.utilities:
        return AppColors.catUtilities;
      case TransactionCategory.entertainment:
        return AppColors.catEntertain;
      case TransactionCategory.shopping:
        return AppColors.catShopping;
      case TransactionCategory.health:
        return AppColors.catHealth;
      case TransactionCategory.education:
        return AppColors.catEducation;
      case TransactionCategory.savings:
        return AppColors.catSavings;
      case TransactionCategory.income:
        return AppColors.catIncome;
      case TransactionCategory.festival:
        return AppColors.catFestival;
      case TransactionCategory.transfer:
        return AppColors.catTransfer;
      case TransactionCategory.other:
        return AppColors.catOther;
    }
  }
}

class CategoryConstants {
  static TransactionCategory fromString(String category) {
    return TransactionCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == category.toLowerCase() || e.toString().split('.').last == category.toLowerCase(),
      orElse: () => TransactionCategory.other,
    );
  }
}
