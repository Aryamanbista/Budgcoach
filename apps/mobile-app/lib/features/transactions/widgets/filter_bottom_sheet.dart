import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/category_constants.dart';

class TransactionFilters {
  final String dateRange; // 'This Month', 'Last Month', 'All'
  final Set<TransactionCategory> selectedCategories;
  final String sortBy; // 'Newest', 'Oldest', 'Highest', 'Lowest'

  TransactionFilters({
    required this.dateRange,
    required this.selectedCategories,
    required this.sortBy,
  });

  factory TransactionFilters.defaultFilters() {
    return TransactionFilters(
      dateRange: 'All',
      selectedCategories: {},
      sortBy: 'Newest',
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  final TransactionFilters initialFilters;
  final ValueChanged<TransactionFilters> onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String _dateRange;
  late Set<TransactionCategory> _selectedCategories;
  late String _sortBy;

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialFilters.dateRange;
    _selectedCategories = Set.from(widget.initialFilters.selectedCategories);
    _sortBy = widget.initialFilters.sortBy;
  }

  void _resetFilters() {
    setState(() {
      _dateRange = 'All';
      _selectedCategories = {};
      _sortBy = 'Newest';
    });
  }

  void _applyFilters() {
    widget.onApply(
      TransactionFilters(
        dateRange: _dateRange,
        selectedCategories: _selectedCategories,
        sortBy: _sortBy,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter Transactions', style: AppTextStyles.titleLarge),
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Reset', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Date Range Section
            Text('Date Range', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: ['This Month', 'Last Month', 'All'].map((range) {
                final isSelected = _dateRange == range;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(range),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _dateRange = range);
                    },
                    selectedColor: AppColors.primary.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Category Section
            Text('Categories', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: TransactionCategory.values.map((cat) {
                final isSelected = _selectedCategories.contains(cat);
                return FilterChip(
                  avatar: Text(cat.emoji),
                  label: Text(cat.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategories.add(cat);
                      } else {
                        _selectedCategories.remove(cat);
                      }
                    });
                  },
                  selectedColor: cat.color.withOpacity(0.15),
                  checkmarkColor: cat.color,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Sort Section
            Text('Sort By', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Column(
              children: ['Newest', 'Oldest', 'Highest', 'Lowest'].map((sort) {
                return RadioListTile<String>(
                  title: Text(sort),
                  value: sort,
                  groupValue: _sortBy,
                  activeColor: AppColors.primary,
                  onChanged: (val) {
                    if (val != null) setState(() => _sortBy = val);
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Apply Button
            ElevatedButton(
              onPressed: _applyFilters,
              child: const Text('Apply Filters'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
