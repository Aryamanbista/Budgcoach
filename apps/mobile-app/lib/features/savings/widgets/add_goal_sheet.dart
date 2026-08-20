import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/savings_goal_model.dart';
import '../providers/savings_provider.dart';

class AddGoalSheet extends ConsumerStatefulWidget {
  const AddGoalSheet({super.key});

  @override
  ConsumerState<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<AddGoalSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _startAmountController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 90));
  String _selectedEmoji = '🎯';

  final List<String> _emojis = [
    '🎯',
    '🛡️',
    '💻',
    '🏔️',
    '🏠',
    '🚗',
    '🎓',
    '✈️',
    '💰',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _startAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _createGoal() {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text);
    final startVal = double.tryParse(_startAmountController.text) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a goal name')));
      return;
    }

    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target amount')),
      );
      return;
    }

    // Calculate monthly contribution recommendation
    final monthsLeft = (_selectedDate.difference(DateTime.now()).inDays / 30.0)
        .clamp(1.0, 120.0);
    final needed = target - startVal;
    final monthly = needed > 0 ? (needed / monthsLeft) : 0.0;

    final newGoal = SavingsGoalModel(
      id: const Uuid().v4(),
      name: name,
      targetAmount: target,
      currentAmount: startVal,
      deadline: _selectedDate,
      emoji: _selectedEmoji,
      monthlyContribution: monthly,
      contributionHistory: startVal > 0
          ? [SavingsContribution(date: DateTime.now(), amount: startVal)]
          : [],
    );

    ref.read(savingsGoalsProvider.notifier).addGoal(newGoal);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Savings goal created!')));
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
              'Create Savings Goal',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Emoji selector row
            Text(
              'Select Icon',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                itemBuilder: (context, index) {
                  final emoji = _emojis[index];
                  final isSelected = _selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Goal Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Goal Name',
                hintText: 'e.g., Emergency Fund',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Target Amount
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target Amount',
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'NPR',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Starting Amount
            TextField(
              controller: _startAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Starting Balance (Optional)',
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'NPR',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Target Date
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Target Date',
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
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _createGoal,
              child: const Text('Create Goal'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
