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

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // Map backend 'type' (debit/credit) and 'amount' to our signed amount
    final double rawAmount = double.parse(json['amount'].toString());
    final bool isDebit = json['type'] == 'debit';
    final signedAmount = isDebit ? -rawAmount : rawAmount;

    // Use clean_text, fallback to transaction_text or raw_text
    final String description = json['clean_text'] ?? 
                              json['transaction_text'] ?? 
                              json['raw_text'] ?? 
                              'Unknown Transaction';

    return TransactionModel(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      description: description,
      amount: signedAmount,
      date: json['transaction_date'] != null 
          ? DateTime.parse(json['transaction_date']) 
          : (json['date'] != null ? DateTime.parse(json['date']) : DateTime.now()),
      category: TransactionCategory.other, // Default for now unless backend categorizes
      source: json['is_manual_entry'] == true ? 'Manual' : 'System',
      notes: json['raw_text'],
      confidence: json['ml_confidence_score'] != null 
          ? double.tryParse(json['ml_confidence_score'].toString()) 
          : null,
    );
  }
}
