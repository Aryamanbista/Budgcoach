import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/category_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/budget_provider.dart';

class SetBudgetSheet extends ConsumerStatefulWidget {
  const SetBudgetSheet({super.key});

  @override
  ConsumerState<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<SetBudgetSheet> {
  final Map<TransactionCategory, TextEditingController> _controllers = {};
  late double _monthlyIncome;

  @override
  void initState() {
    super.initState();
    final limits = ref.read(budgetLimitsProvider);
    final user = ref.read(authProvider).user;
    _monthlyIncome = user?.monthlyIncome ?? 35000;

    // We only allocate budgets for spending categories (exclude Income and Transfer)
    for (var cat in TransactionCategory.values) {
      if (cat != TransactionCategory.income && cat != TransactionCategory.transfer) {
        final currentLimit = limits[cat] ?? 0.0;
        _controllers[cat] = TextEditingController(
          text: currentLimit > 0 ? currentLimit.toInt().toString() : '0',
        );
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _calculateTotalAllocated() {
    double total = 0.0;
    _controllers.forEach((cat, controller) {
      // Exclude income/transfer
      if (cat != TransactionCategory.income && cat != TransactionCategory.transfer) {
        total += double.tryParse(controller.text) ?? 0.0;
      }
    });
    return total;
  }

  void _saveBudgets() {
    final Map<TransactionCategory, double> newLimits = {};
    final originalLimits = ref.read(budgetLimitsProvider);
    
    // Copy original limits (so Income limit and Transfer limit stay preserved)
    originalLimits.forEach((cat, limit) {
      newLimits[cat] = limit;
    });

    // Update with controller values
    _controllers.forEach((cat, controller) {
      newLimits[cat] = double.tryParse(controller.text) ?? 0.0;
    });

    ref.read(budgetLimitsProvider.notifier).setLimits(newLimits);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Monthly budget settings updated')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final totalAllocated = _calculateTotalAllocated();
    final remainingToAllocate = _monthlyIncome - totalAllocated;
    final isOverAllocated = remainingToAllocate < 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Set Monthly Budget',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Header stats
            Card(
              color: isOverAllocated ? AppColors.danger.withOpacity(0.08) : AppColors.primary.withOpacity(0.08),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Monthly Income', style: AppTextStyles.bodyMedium),
                        Text(Formatters.formatNpr(_monthlyIncome), style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isOverAllocated ? 'Over-allocated' : 'Remaining to Allocate',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isOverAllocated ? AppColors.danger : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          Formatters.formatNpr(remainingToAllocate),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isOverAllocated ? AppColors.danger : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable Category Limit list
            Expanded(
              child: ListView(
                children: _controllers.keys.map((cat) {
                  final controller = _controllers[cat]!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Text(cat.name, style: AppTextStyles.bodyLarge),
                        ),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.end,
                            onChanged: (val) {
                              setState(() {}); // Rebuild to calculate remaining total
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text('NPR', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Save Button
            ElevatedButton(
              onPressed: _saveBudgets,
              child: const Text('Save Budget'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
