import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/category_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../../transactions/providers/transactions_provider.dart';

class ReviewTransactionsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> importPreview;

  const ReviewTransactionsScreen({super.key, required this.importPreview});

  @override
  ConsumerState<ReviewTransactionsScreen> createState() =>
      _ReviewTransactionsScreenState();
}

class _ReviewRow {
  final int rowIndex;
  final String duplicateStatus;
  final List<String> messages;
  final double confidence;
  DateTime? date;
  String type;
  double amount;
  String description;
  TransactionCategory category;
  bool include;

  _ReviewRow({
    required this.rowIndex,
    required this.duplicateStatus,
    required this.messages,
    required this.confidence,
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
    required this.category,
    required this.include,
  });

  factory _ReviewRow.fromJson(Map<String, dynamic> json) {
    final status = json['duplicate_status']?.toString() ?? 'new';
    return _ReviewRow(
      rowIndex: int.parse(json['row_index'].toString()),
      duplicateStatus: status,
      messages: (json['validation_messages'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      confidence: double.tryParse(json['confidence'].toString()) ?? 1,
      date: json['date'] == null
          ? null
          : DateTime.tryParse(json['date'].toString()),
      type: json['type']?.toString() ?? 'debit',
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      description: json['clean_text']?.toString() ?? '',
      category: TransactionCategory.other,
      include: status == 'new',
    );
  }

  bool get isImportable =>
      duplicateStatus != 'exact' && duplicateStatus != 'invalid';
}

class _ReviewTransactionsScreenState
    extends ConsumerState<ReviewTransactionsScreen> {
  late final List<_ReviewRow> _rows;
  bool _isCommitting = false;
  String? _errorMessage;

  String get _batchId => widget.importPreview['batch_id']?.toString() ?? '';
  String get _batchStatus =>
      widget.importPreview['status']?.toString() ?? 'previewed';
  bool get _isCompleted => _batchStatus == 'completed';
  int get _selectedCount => _rows.where((row) => row.include).length;

  @override
  void initState() {
    super.initState();
    final rawRows =
        widget.importPreview['transactions'] as List<dynamic>? ?? const [];
    _rows = rawRows
        .map(
          (item) => _ReviewRow.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> _confirmImport() async {
    if (_batchId.isEmpty || _isCompleted) return;

    setState(() {
      _isCommitting = true;
      _errorMessage = null;
    });

    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .post(
            '/import-batches/$_batchId/commit',
            data: {
              'rows': _rows
                  .map(
                    (row) => {
                      'row_index': row.rowIndex,
                      'include': row.include,
                      'date': row.date?.toIso8601String().split('T').first,
                      'type': row.type,
                      'amount': row.amount,
                      'clean_text': row.description.trim(),
                      'category_name': row.category.displayName,
                    },
                  )
                  .toList(),
            },
          );
      await ref.read(transactionsProvider.notifier).fetchTransactions();

      if (!mounted) return;
      final imported = response.data['imported_count'] ?? 0;
      final skipped = response.data['duplicates_skipped'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported $imported transactions'
            '${skipped == 0 ? '' : ' · skipped $skipped duplicates'}',
          ),
        ),
      );
      context.go('/home/transactions');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'The import could not be completed. Review highlighted rows and try again.';
      });
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Transactions'), elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            _buildSummary(),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(child: Text('No transactions were extracted.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _rows.length,
                      itemBuilder: (context, index) =>
                          _buildRowCard(_rows[index]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _selectedCount == 0 || _isCommitting || _isCompleted
                    ? null
                    : _confirmImport,
                child: Text(
                  _isCompleted
                      ? 'ALREADY IMPORTED'
                      : _isCommitting
                      ? 'IMPORTING…'
                      : 'IMPORT $_selectedCount TRANSACTIONS',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final isReplay = widget.importPreview['file_reused'] == true;
    final newCount = widget.importPreview['new_count'] ?? 0;
    final exactCount = widget.importPreview['exact_duplicates'] ?? 0;
    final possibleCount = widget.importPreview['possible_duplicates'] ?? 0;
    final invalidCount = widget.importPreview['validation_errors'] ?? 0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReplay)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _isCompleted
                      ? 'This file was already imported.'
                      : 'This file was processed earlier; the saved review is shown.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _summaryChip('$newCount new', AppColors.success),
                _summaryChip('$exactCount exact duplicates', AppColors.danger),
                _summaryChip(
                  '$possibleCount need confirmation',
                  AppColors.secondary,
                ),
                _summaryChip('$invalidCount invalid', AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRowCard(_ReviewRow row) {
    final statusColor = switch (row.duplicateStatus) {
      'exact' => AppColors.danger,
      'possible' => AppColors.secondary,
      'invalid' => AppColors.textSecondary,
      _ => AppColors.success,
    };
    final statusLabel = switch (row.duplicateStatus) {
      'exact' => 'EXACT DUPLICATE',
      'possible' => 'POSSIBLE DUPLICATE',
      'invalid' => 'INVALID',
      _ => row.confidence < 0.75 ? 'REVIEW' : 'NEW',
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: row.description,
                    enabled: row.isImportable && !_isCompleted,
                    onChanged: (value) => row.description = value,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                Text(
                  Formatters.formatNpr(
                    row.type == 'debit' ? -row.amount : row.amount,
                    showSign: true,
                  ),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: row.type == 'debit'
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    statusLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  row.date == null
                      ? 'Unknown date'
                      : Formatters.formatDate(row.date!),
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
            if (row.messages.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...row.messages.map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• $message',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TransactionCategory>(
                    initialValue: row.category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      isDense: true,
                    ),
                    items: TransactionCategory.values
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(
                              '${category.emoji} ${category.displayName}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: row.isImportable && !_isCompleted
                        ? (value) {
                            if (value != null) {
                              setState(() => row.category = value);
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                if (row.duplicateStatus == 'possible')
                  FilterChip(
                    label: const Text('Import anyway'),
                    selected: row.include,
                    onSelected: _isCompleted
                        ? null
                        : (selected) => setState(() => row.include = selected),
                  )
                else
                  Checkbox(
                    value: row.include,
                    onChanged: row.isImportable && !_isCompleted
                        ? (selected) =>
                              setState(() => row.include = selected ?? false)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
