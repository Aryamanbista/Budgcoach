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
  const ReviewTransactionsScreen({super.key});

  @override
  ConsumerState<ReviewTransactionsScreen> createState() => _ReviewTransactionsScreenState();
}

class _ReviewTransactionsScreenState extends ConsumerState<ReviewTransactionsScreen> {
  late List<TransactionModel> _extractedTxs;

  @override
  void initState() {
    super.initState();
    // Prepare 12 mock extracted transactions
    final now = DateTime.now();
    _extractedTxs = [
      TransactionModel(
        id: 'ocr_001',
        description: 'Bhat Bhateni Store',
        amount: -2200,
        date: now,
        category: TransactionCategory.food,
        source: 'eSewa OCR',
      ),
      TransactionModel(
        id: 'ocr_002',
        description: 'Momo Hut Lalitpur',
        amount: -600,
        date: now,
        category: TransactionCategory.food,
        source: 'eSewa OCR',
      ),
      TransactionModel(
        id: 'ocr_003',
        description: 'Pathao Taxi Ride',
        amount: -350,
        date: now,
        category: TransactionCategory.transport,
        source: 'eSewa OCR',
      ),
      TransactionModel(
        id: 'ocr_004',
        description: 'Daraz Nepal Shopping',
        amount: -1500,
        date: now.subtract(const Duration(days: 1)),
        category: TransactionCategory.shopping,
        source: 'eSewa OCR',
      ),
      // Duplicate set
      TransactionModel(
        id: 'ocr_005',
        description: 'NEA Electricity Payment',
        amount: -1200,
        date: now.subtract(const Duration(days: 1)),
        category: TransactionCategory.utilities,
        source: 'eSewa OCR',
      ),
      TransactionModel(
        id: 'ocr_006',
        description: 'NEA Electricity Payment',
        amount: -1200,
        date: now.subtract(const Duration(days: 1)),
        category: TransactionCategory.utilities,
        source: 'eSewa OCR', // Mark this as duplicate
      ),
      TransactionModel(
        id: 'ocr_007',
        description: 'QFX Cinemas ticket',
        amount: -750,
        date: now.subtract(const Duration(days: 2)),
        category: TransactionCategory.entertainment,
        source: 'eSewa OCR',
      ),
      TransactionModel(
        id: 'ocr_008',
        description: 'Alka Pharmacy Medicine',
        amount: -450,
        date: now.subtract(const Duration(days: 2)),
        category: TransactionCategory.health,
        source: 'eSewa OCR',
      ),
      TransactionModel(
        id: 'ocr_009',
        description: 'Stationery Books',
        amount: -350,
        date: now.subtract(const Duration(days: 3)),
        category: TransactionCategory.education,
        source: 'eSewa OCR',
      ),
      TransactionModel(
        id: 'ocr_010',
        description: 'Cash Withdrawal',
        amount: -2000,
        date: now.subtract(const Duration(days: 3)),
        category: TransactionCategory.other,
        source: 'eSewa OCR',
      ),
      TransactionModel(
        id: 'ocr_011',
        description: 'Khalti Fund Transfer',
        amount: -1000,
        date: now.subtract(const Duration(days: 4)),
        category: TransactionCategory.transfer,
        source: 'eSewa OCR',
      ),
      TransactionModel(
        id: 'ocr_012',
        description: 'Pocket Money from Father',
        amount: 5000,
        date: now.subtract(const Duration(days: 4)),
        category: TransactionCategory.income,
        source: 'eSewa OCR',
      ),
    ];
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
          source: 'eSewa Statement Import',
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
                  // Let's mark the 6th item (NEA duplicates index 5) as DUP
                  final isDuplicate = index == 5;
                  
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
