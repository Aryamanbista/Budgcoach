import '../../core/constants/category_constants.dart';

class TransactionModel {
  final String id;
  final String description;
  final double amount; // negative for expense, positive for income
  final DateTime date;
  final TransactionCategory category;
  final String source; // e.g., 'eSewa', 'Khalti', 'Manual', 'Nabil Bank'
  final String? notes;
  final double? confidence; // e.g., 0.87 (only for OCR-categorized items)

  TransactionModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    required this.source,
    this.notes,
    this.confidence,
  });

  bool get isIncome => amount > 0;
  bool get isExpense => amount < 0;

  TransactionModel copyWith({
    String? id,
    String? description,
    double? amount,
    DateTime? date,
    TransactionCategory? category,
    String? source,
    String? notes,
    double? confidence,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      confidence: confidence ?? this.confidence,
    );
  }
}
