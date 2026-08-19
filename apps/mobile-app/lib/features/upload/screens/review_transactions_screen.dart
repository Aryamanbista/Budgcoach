import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/category_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/transaction_model.dart';
import '../../transactions/providers/transactions_provider.dart';

class ReviewTransactionsScreen extends ConsumerStatefulWidget {
  final List<dynamic> parsedTransactions;
  const ReviewTransactionsScreen({super.key, required this.parsedTransactions});

  @override
  ConsumerState<ReviewTransactionsScreen> createState() => _ReviewTransactionsScreenState();
}

class _ReviewTransactionsScreenState extends ConsumerState<ReviewTransactionsScreen> {
  late List<TransactionModel> _extractedTxs;

  @override
  void initState() {
    super.initState();
    _extractedTxs = widget.parsedTransactions.map((json) {
      return TransactionModel.fromJson(json as Map<String, dynamic>);
    }).toList();
  }

  void _updateTxDescription(int index, String value) {
    setState(() {
      _extractedTxs[index] = _extractedTxs[index].copyWith(description: value);
    });
  }

  void _updateTxCategory(int index, TransactionCategory category) {
    setState(() {
      _extractedTxs[index] = _extractedTxs[index].copyWith(category: category);
    });
  }

  void _confirmImport() {
    // Import all to transactions state notifier
    final notifier = ref.read(transactionsProvider.notifier);
    for (var tx in _extractedTxs) {
      notifier.addTransaction(
        TransactionModel(
          id: const Uuid().v4(),
          description: tx.description,
          amount: tx.amount,
          date: tx.date,
          category: tx.category,
          source: 'Statement Import',
          notes: 'Imported from statement file',
          confidence: 0.90,
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully imported ${_extractedTxs.length} transactions!')),
    );
    
    // Go to Transactions Tab
    context.go('/home/transactions');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Review Transactions'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_extractedTxs.length}',
                style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _extractedTxs.length,
                itemBuilder: (context, index) {
                  final tx = _extractedTxs[index];
                  final isDuplicate = widget.parsedTransactions[index]['is_duplicate'] == true;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Editable Title
                              Expanded(
                                child: TextFormField(
                                  initialValue: tx.description,
                                  onChanged: (val) => _updateTxDescription(index, val),
                                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              
                              // Amount display & DUP badge
                              Row(
                                children: [
                                  if (isDuplicate) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppColors.secondary),
                                      ),
                                      child: const Text(
                                        'DUP',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    Formatters.formatNpr(tx.amount, showSign: true),
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: tx.amount < 0 ? AppColors.danger : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 4),
                          
                          // Editable Category dropdown
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Category',
                                style: AppTextStyles.labelSmall.copyWith(fontSize: 12),
                              ),
                              SizedBox(
                                width: 180,
                                height: 40,
                                child: DropdownButtonFormField<TransactionCategory>(
                                  value: tx.category,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  items: TransactionCategory.values
                                      .map((cat) => DropdownMenuItem(
                                            value: cat,
                                            child: Row(
                                              children: [
                                                Text(cat.emoji),
                                                const SizedBox(width: 8),
                                                Text(cat.name, style: const TextStyle(fontSize: 13)),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      _updateTxCategory(index, val);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Confirm Import Footer Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _confirmImport,
                child: Text('Confirm & Import ${_extractedTxs.length} Transactions'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
