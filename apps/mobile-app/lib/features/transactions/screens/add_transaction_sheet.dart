import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/category_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/transaction_model.dart';
import '../providers/transactions_provider.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionCategory _selectedCategory = TransactionCategory.food;
  DateTime _selectedDate = DateTime.now();
  bool _isExpense = true;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTransaction() {
    final amountVal = double.tryParse(_amountController.text);
    final descriptionVal = _descriptionController.text.trim();

    if (amountVal == null || amountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (descriptionVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    final finalAmount = _isExpense ? -amountVal : amountVal;

    final newTx = TransactionModel(
      id: const Uuid().v4(),
      description: descriptionVal,
      amount: finalAmount,
      date: _selectedDate,
      category: _selectedCategory,
      source: 'Manual Entry',
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    ref.read(transactionsProvider.notifier).addTransaction(newTx);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction saved successfully')),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
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
              'Add Transaction',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Toggle Expense / Income
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Expense'),
                    selected: _isExpense,
                    onSelected: (val) {
                      setState(() {
                        _isExpense = true;
                      });
                    },
                    selectedColor: AppColors.danger.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: _isExpense
                          ? AppColors.danger
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Income'),
                    selected: !_isExpense,
                    onSelected: (val) {
                      setState(() {
                        _isExpense = false;
                        _selectedCategory = TransactionCategory.income;
                      });
                    },
                    selectedColor: AppColors.success.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: !_isExpense
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Input
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppTextStyles.headlineMedium,
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'NPR',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description Input
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Bhat Bhateni Supermarket',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Selector
            DropdownButtonFormField<TransactionCategory>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
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
                          Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Text(cat.displayName),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategory = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Date Picker
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  Formatters.formatDate(_selectedDate),
                  style: AppTextStyles.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes Input
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add description details...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _saveTransaction,
              child: const Text('Save Transaction'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
