import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/category_constants.dart';
import '../../../shared/models/transaction_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../../transactions/screens/add_transaction_sheet.dart';
import '../../transactions/widgets/transaction_list_item.dart';
import '../../budget/providers/budget_provider.dart';
import '../../nudges/providers/nudges_provider.dart';
import '../../../shared/models/nudge_model.dart';
import '../../../core/mock/mock_data.dart';
import '../widgets/health_score_badge.dart';
import '../widgets/spending_summary_card.dart';
import '../widgets/category_chips_row.dart';
import '../widgets/nudge_alert_banner.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final transactions = ref.watch(transactionsProvider);
    final budgets = ref.watch(budgetsProvider);
    final nudges = ref.watch(nudgesProvider);

    // Calculate budget & spent values dynamically
    // Exclude Income and Transfer from spending card totals
    final spendingBudgets = budgets.where((b) =>
        b.category != TransactionCategory.income &&
        b.category != TransactionCategory.transfer &&
        b.category != TransactionCategory.savings);
        
    final totalBudget = spendingBudgets.fold(0.0, (sum, b) => sum + b.limit);
    final totalSpent = spendingBudgets.fold(0.0, (sum, b) => sum + b.spent);

    // Find the first active WARNING nudge
    final activeWarningNudge = nudges.firstWhere(
      (n) => n.severity == NudgeSeverity.warning && !n.isDismissed,
      orElse: () => NudgeModel(
        id: '',
        title: '',
        description: '',
        severity: NudgeSeverity.warning,
        date: DateTime.now(),
      ),
    );

    // Dynamic Category spending chips
    final Map<TransactionCategory, double> catSpending = {};
    for (var tx in transactions) {
      if (tx.amount < 0) {
        catSpending[tx.category] = (catSpending[tx.category] ?? 0.0) + tx.amount.abs();
      }
    }
    
    final chipItems = catSpending.entries
        .map((e) => CategoryChipItem(category: e.key, amount: e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    
    // Top 5 categories
    final topChips = chipItems.take(5).toList();

    // Last 5 transactions
    final recentTransactions = transactions.take(5).toList();

    // Days remaining in June 2026 (Since prompt uses June 2026 as context, let's say 23 days left)
    const daysLeft = 23;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Budgcoach',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            key: const Key('dashboard_avatar'),
            child: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: Text(
                'AB',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good morning, ${authState.user?.name.split(' ').first ?? 'Aryaman'}! 👋',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'June 2026 · Kathmandu, Nepal',
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                  HealthScoreBadge(
                    score: MockData.healthScoreValue,
                    onTap: () => context.push('/health-score'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Spending summary card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SpendingSummaryCard(
                totalBudget: totalBudget > 0 ? totalBudget : 30000,
                totalSpent: totalSpent,
                daysLeft: daysLeft,
              ),
            ),
            const SizedBox(height: 16),

            // Active Nudge Alert Banner
            if (activeWarningNudge.id.isNotEmpty)
              NudgeAlertBanner(
                id: activeWarningNudge.id,
                message: activeWarningNudge.description,
                onDismiss: () {
                  ref.read(nudgesProvider.notifier).dismissNudge(activeWarningNudge.id);
                },
              ),

            // Category Spending title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Top Categories This Month',
                style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
              ),
            ),

            // Category scrolling row
            if (topChips.isNotEmpty)
              CategoryChipsRow(items: topChips)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('No category expenses recorded yet.', style: AppTextStyles.bodyMedium),
              ),
            const SizedBox(height: 16),

            // Recent transactions title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
                  ),
                  TextButton(
                    onPressed: () => context.go('/home/transactions'),
                    child: const Text('See all →'),
                  ),
                ],
              ),
            ),

            // Transactions list
            if (recentTransactions.isNotEmpty)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentTransactions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
                  itemBuilder: (context, index) {
                    final tx = recentTransactions[index];
                    return TransactionListItem(
                      transaction: tx,
                      onTap: () => context.push('/transaction/${tx.id}'),
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No transactions yet.', style: AppTextStyles.bodyMedium),
                ),
              ),
            const SizedBox(height: 24),

            // Quick actions title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Quick Actions',
                style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),

            // Quick Actions Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickAction(
                    context: context,
                    icon: Icons.upload_file,
                    label: 'Upload',
                    onTap: () => context.go('/home/upload'),
                  ),
                  _buildQuickAction(
                    context: context,
                    icon: Icons.add,
                    label: 'Add',
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => const AddTransactionSheet(),
                      );
                    },
                  ),
                  _buildQuickAction(
                    context: context,
                    icon: Icons.track_changes,
                    label: 'Goals',
                    onTap: () => context.push('/savings'),
                  ),
                  _buildQuickAction(
                    context: context,
                    icon: Icons.bar_chart,
                    label: 'Forecast',
                    onTap: () => context.push('/forecast'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
