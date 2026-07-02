import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../providers/savings_provider.dart';

class GoalDetailScreen extends ConsumerStatefulWidget {
  final String goalId;

  const GoalDetailScreen({
    super.key,
    required this.goalId,
  });

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  final _contribController = TextEditingController();

  @override
  void dispose() {
    _contribController.dispose();
    super.dispose();
  }

  void _showAddContributionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
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
              Text('Add Contribution', style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                controller: _contribController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Contribution Amount',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('NPR', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(_contribController.text);
                  if (amount != null && amount > 0) {
                    ref.read(savingsGoalsProvider.notifier).addContribution(widget.goalId, amount);
                    _contribController.clear();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contribution recorded!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                  }
                },
                child: const Text('Add Contribution'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(savingsGoalsProvider);
    final goalIndex = goals.indexWhere((g) => g.id == widget.goalId);

    if (goalIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Goal Details')),
        body: const Center(child: Text('Goal not found.')),
      );
    }

    final goal = goals[goalIndex];
    final percentage = goal.progressPercentage;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.danger),
            onPressed: () {
              // Delete confirmation dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Savings Goal?'),
                  content: const Text('Are you sure you want to permanently delete this savings goal?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(savingsGoalsProvider.notifier).deleteGoal(goal.id);
                        Navigator.of(context).pop(); // dismiss dialog
                        context.pop(); // go back
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Goal deleted')),
                        );
                      },
                      child: const Text('DELETE', style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Large Emoji Header
                      Text(goal.emoji, style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text(
                        goal.name,
                        style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Progress Circle Gauge
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: CircularProgressIndicator(
                              value: percentage.clamp(0.0, 1.0),
                              strokeWidth: 10,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          Text(
                            '${(percentage * 100).toInt()}%',
                            style: AppTextStyles.displayLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Metrics summary card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildMetricRow('Saved Amount', Formatters.formatNpr(goal.currentAmount), color: AppColors.primary),
                              const Divider(),
                              _buildMetricRow('Target Goal', Formatters.formatNpr(goal.targetAmount)),
                              const Divider(),
                              _buildMetricRow('Remaining Needed', Formatters.formatNpr(goal.remainingAmount.clamp(0.0, goal.targetAmount)), color: AppColors.danger),
                              const Divider(),
                              _buildMetricRow('Target Deadline', DateFormat('dd MMMM yyyy').format(goal.deadline)),
                              const Divider(),
                              _buildMetricRow('Monthly Saving Suggestion', Formatters.formatNpr(goal.monthlyContribution), isBold: true),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Contribution History list
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Contribution History',
                          style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (goal.contributionHistory.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Text('No savings entries yet.', style: AppTextStyles.bodyMedium),
                            ),
                          ),
                        )
                      else
                        Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: goal.contributionHistory.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final contribution = goal.contributionHistory[index];
                              return ListTile(
                                leading: const Icon(Icons.add_circle, color: AppColors.primary),
                                title: Text(
                                  Formatters.formatNpr(contribution.amount),
                                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                ),
                                trailing: Text(
                                  DateFormat('dd MMM yyyy').format(contribution.date),
                                  style: AppTextStyles.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            
            // Add Contribution Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => _showAddContributionSheet(context),
                child: const Text('Add Contribution'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: isBold || color != null ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
