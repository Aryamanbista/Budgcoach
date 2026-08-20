import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../providers/savings_provider.dart';
import '../widgets/add_goal_sheet.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals'), elevation: 0),
      body: goalsAsync.when(
        data: (goals) => goals.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      'No savings goals yet',
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a savings goal to start tracking milestones.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => const AddGoalSheet(),
                        );
                      },
                      child: const Text('Create Savings Goal'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final percentage = goal.progressPercentage;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: InkWell(
                      onTap: () => context.push('/savings/${goal.id}'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Emoji + Title + Monthly contribution
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      goal.emoji,
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      goal.name,
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${Formatters.formatNpr(goal.monthlyContribution)}/mo',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage.clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Target metrics & deadline
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${Formatters.formatNpr(goal.currentAmount)} / ${Formatters.formatNpr(goal.targetAmount)} (${(percentage * 100).toInt()}%)',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'By ${DateFormat('MMM yyyy').format(goal.deadline)}',
                                  style: AppTextStyles.labelSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Goal advice subtext
                            Text(
                              'Save ${Formatters.formatNpr(goal.monthlyContribution)}/month to reach your goal',
                              style: AppTextStyles.labelSmall.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => const AddGoalSheet(),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
