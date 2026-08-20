import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/category_constants.dart';
import '../../../core/utils/formatters.dart';
import '../providers/transactions_provider.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);

    // Find the transaction
    final transactionIndex = transactions.indexWhere(
      (tx) => tx.id == transactionId,
    );

    if (transactionIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Details')),
        body: const Center(child: Text('Transaction not found.')),
      );
    }

    final tx = transactions[transactionIndex];
    final isExpense = tx.amount < 0;
    final catColor = tx.category.color;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details'), elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      // Large Emoji Circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tx.category.emoji,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        tx.description,
                        style: AppTextStyles.headlineMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Amount
                      Text(
                        Formatters.formatNpr(tx.amount, showSign: true),
                        style: AppTextStyles.displayLarge.copyWith(
                          color: isExpense
                              ? AppColors.danger
                              : AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Card detail rows
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildDetailRow(
                                label: 'Date',
                                value: DateFormat(
                                  'dd/MM/yyyy · h:mm a',
                                ).format(tx.date),
                              ),
                              const Divider(),
                              _buildDetailRow(
                                label: 'Category',
                                value: tx.category.displayName,
                              ),
                              const Divider(),
                              _buildDetailRow(
                                label: 'Source Wallet/Bank',
                                value: tx.source,
                              ),
                              if (tx.notes != null) ...[
                                const Divider(),
                                _buildDetailRow(
                                  label: 'Notes',
                                  value: tx.notes!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ML Categorization Confidence Bar (If statement-derived)
                      if (tx.confidence != null) ...[
                        Card(
                          color: AppColors.primary.withOpacity(0.05),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: AppColors.primary.withOpacity(0.15),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'AI Classification Confidence',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${(tx.confidence! * 100).toInt()}%',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: tx.confidence!,
                                    minHeight: 8,
                                    backgroundColor: AppColors.primary
                                        .withOpacity(0.15),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppColors.primary,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This transaction was imported and categorized using Budgcoach ML.',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Category override dropdown selector
                      DropdownButtonFormField<TransactionCategory>(
                        value: tx.category,
                        decoration: InputDecoration(
                          labelText: 'Override Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: TransactionCategory.values
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Row(
                                  children: [
                                    Text(
                                      cat.emoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(cat.displayName),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            ref
                                .read(transactionsProvider.notifier)
                                .overrideCategory(tx.id, val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Category changed to ${val.name}',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Delete Button
              ElevatedButton(
                onPressed: () {
                  // Confirm Dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Transaction?'),
                      content: const Text(
                        'Are you sure you want to permanently delete this transaction?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(transactionsProvider.notifier)
                                .deleteTransaction(tx.id);
                            Navigator.of(context).pop(); // Dismiss dialog
                            context.pop(); // Go back to transaction screen
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaction deleted'),
                              ),
                            );
                          },
                          child: const Text(
                            'DELETE',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: const Text('Delete Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
