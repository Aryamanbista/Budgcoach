import '../../shared/models/user_model.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/models/budget_model.dart';
import '../../shared/models/savings_goal_model.dart';
import '../../shared/models/nudge_model.dart';
import '../constants/category_constants.dart';

class ForecastPoint {
  final int day;
  final double amount;
  final bool isPrediction;

  ForecastPoint({
    required this.day,
    required this.amount,
    required this.isPrediction,
  });
}

class MockData {
  // Mock User
  static UserModel mockUser = UserModel(
    id: 'user_mock_001',
    name: 'Aryaman Bista',
    email: 'aryaman@example.com',
    occupation: 'Student',
    monthlyIncome: 35000,
  );

  // Mock Transactions (In-memory list, modifiable for interactive mock state)
  static List<TransactionModel> mockTransactions = [
    TransactionModel(
      id: 'tx_001',
      description: 'Bhat Bhateni Supermarket',
      amount: -1200,
      date: DateTime.now(),
      category: TransactionCategory.food,
      source: 'eSewa',
      notes: 'Weekly grocery run',
      confidence: 0.94,
    ),
    TransactionModel(
      id: 'tx_002',
      description: 'eSewa Cash In',
      amount: 5000,
      date: DateTime.now(),
      category: TransactionCategory.transfer,
      source: 'eSewa',
      notes: 'Transfer from bank account',
    ),
    TransactionModel(
      id: 'tx_003',
      description: 'Pathao Ride',
      amount: -250,
      date: DateTime.now().subtract(const Duration(days: 1)),
      category: TransactionCategory.transport,
      source: 'Khalti',
      confidence: 0.98,
    ),
    TransactionModel(
      id: 'tx_004',
      description: 'Burger House & Crunchy Fried Chicken',
      amount: -850,
      date: DateTime.now().subtract(const Duration(days: 1)),
      category: TransactionCategory.food,
      source: 'Manual',
      notes: 'Lunch with friends',
    ),
    TransactionModel(
      id: 'tx_005',
      description: 'Ncell Mobile Recharge',
      amount: -500,
      date: DateTime.now().subtract(const Duration(days: 2)),
      category: TransactionCategory.utilities,
      source: 'eSewa',
      notes: 'Data pack activation',
      confidence: 0.88,
    ),
    TransactionModel(
      id: 'tx_006',
      description: 'QFX Cinemas ticket',
      amount: -700,
      date: DateTime.now().subtract(const Duration(days: 2)),
      category: TransactionCategory.entertainment,
      source: 'Khalti',
      confidence: 0.92,
    ),
    TransactionModel(
      id: 'tx_007',
      description: 'Salary Credit - Freelance',
      amount: 35000,
      date: DateTime.now().subtract(const Duration(days: 3)),
      category: TransactionCategory.income,
      source: 'Nabil Bank',
    ),
    TransactionModel(
      id: 'tx_008',
      description: 'Daraz Online Shopping',
      amount: -4300,
      date: DateTime.now().subtract(const Duration(days: 3)),
      category: TransactionCategory.shopping,
      source: 'eSewa',
      notes: 'Mechanical Keyboard purchase',
      confidence: 0.87,
    ),
    TransactionModel(
      id: 'tx_009',
      description: 'College Semester Exam Fee',
      amount: -3000,
      date: DateTime.now().subtract(const Duration(days: 4)),
      category: TransactionCategory.education,
      source: 'Nabil Bank',
    ),
    TransactionModel(
      id: 'tx_010',
      description: 'Local Bus Fare',
      amount: -50,
      date: DateTime.now().subtract(const Duration(days: 4)),
      category: TransactionCategory.transport,
      source: 'Manual',
    ),
    TransactionModel(
      id: 'tx_011',
      description: 'Sewa Pharmacy (Medicine)',
      amount: -850,
      date: DateTime.now().subtract(const Duration(days: 5)),
      category: TransactionCategory.health,
      source: 'Khalti',
      confidence: 0.91,
    ),
    TransactionModel(
      id: 'tx_012',
      description: 'Tea & Snacks',
      amount: -120,
      date: DateTime.now().subtract(const Duration(days: 5)),
      category: TransactionCategory.food,
      source: 'Manual',
    ),
    TransactionModel(
      id: 'tx_013',
      description: 'Worldlink Internet Bill',
      amount: -1200,
      date: DateTime.now().subtract(const Duration(days: 10)),
      category: TransactionCategory.utilities,
      source: 'eSewa',
      confidence: 0.95,
    ),
    TransactionModel(
      id: 'tx_014',
      description: 'Groceries Local Shop',
      amount: -1500,
      date: DateTime.now().subtract(const Duration(days: 12)),
      category: TransactionCategory.food,
      source: 'Manual',
    ),
    TransactionModel(
      id: 'tx_015',
      description: 'Petrol Refill',
      amount: -1000,
      date: DateTime.now().subtract(const Duration(days: 15)),
      category: TransactionCategory.transport,
      source: 'Khalti',
    ),
    TransactionModel(
      id: 'tx_016',
      description: 'Heritage Book Store',
      amount: -800,
      date: DateTime.now().subtract(const Duration(days: 18)),
      category: TransactionCategory.education,
      source: 'Manual',
      notes: 'Algorithms reference book',
    ),
    TransactionModel(
      id: 'tx_017',
      description: 'Fit & Fine Gym Monthly',
      amount: -1500,
      date: DateTime.now().subtract(const Duration(days: 20)),
      category: TransactionCategory.health,
      source: 'Manual',
    ),
    TransactionModel(
      id: 'tx_018',
      description: 'Steam Wallet Purchase',
      amount: -1100,
      date: DateTime.now().subtract(const Duration(days: 22)),
      category: TransactionCategory.entertainment,
      source: 'Khalti',
      confidence: 0.82,
    ),
    TransactionModel(
      id: 'tx_019',
      description: 'NEA Electricity Bill',
      amount: -700,
      date: DateTime.now().subtract(const Duration(days: 25)),
      category: TransactionCategory.utilities,
      source: 'eSewa',
      confidence: 0.96,
    ),
    TransactionModel(
      id: 'tx_020',
      description: 'Momo with Friends',
      amount: -650,
      date: DateTime.now().subtract(const Duration(days: 28)),
      category: TransactionCategory.food,
      source: 'eSewa',
    ),
    TransactionModel(
      id: 'tx_021',
      description: 'Transfer to Mother',
      amount: -5000,
      date: DateTime.now().subtract(const Duration(days: 29)),
      category: TransactionCategory.transfer,
      source: 'Nabil Bank',
    ),
    TransactionModel(
      id: 'tx_022',
      description: 'Daraz UI Design Freelance Payment',
      amount: 8000,
      date: DateTime.now().subtract(const Duration(days: 30)),
      category: TransactionCategory.income,
      source: 'Nabil Bank',
    ),
  ];

  // Mock Budgets (Current Month)
  static List<BudgetModel> mockBudgets = [
    BudgetModel(category: TransactionCategory.food, limit: 8000, spent: 5200),
    BudgetModel(
      category: TransactionCategory.transport,
      limit: 3000,
      spent: 2100,
    ),
    BudgetModel(
      category: TransactionCategory.utilities,
      limit: 2000,
      spent: 1200,
    ),
    BudgetModel(
      category: TransactionCategory.entertainment,
      limit: 2500,
      spent: 1800,
    ),
    BudgetModel(
      category: TransactionCategory.shopping,
      limit: 4000,
      spent: 4300,
    ), // Over budget!
    BudgetModel(category: TransactionCategory.health, limit: 1500, spent: 850),
    BudgetModel(
      category: TransactionCategory.education,
      limit: 5000,
      spent: 3000,
    ),
    BudgetModel(category: TransactionCategory.savings, limit: 10000, spent: 0),
    BudgetModel(
      category: TransactionCategory.income,
      limit: 35000,
      spent: 43000,
    ), // Freelance + Salary
    BudgetModel(category: TransactionCategory.festival, limit: 5000, spent: 0),
    BudgetModel(category: TransactionCategory.transfer, limit: 0, spent: 5000),
    BudgetModel(category: TransactionCategory.other, limit: 2000, spent: 0),
  ];

  // Mock Savings Goals
  static List<SavingsGoalModel> mockSavingsGoals = [
    SavingsGoalModel(
      id: 'goal_001',
      name: 'Emergency Fund',
      targetAmount: 50000,
      currentAmount: 15000,
      deadline: DateTime(2026, 12, 31),
      emoji: '🛡️',
      monthlyContribution: 5000,
      contributionHistory: [
        SavingsContribution(date: DateTime(2026, 3, 1), amount: 5000),
        SavingsContribution(date: DateTime(2026, 4, 1), amount: 5000),
        SavingsContribution(date: DateTime(2026, 5, 1), amount: 5000),
      ],
    ),
    SavingsGoalModel(
      id: 'goal_002',
      name: 'New Laptop',
      targetAmount: 80000,
      currentAmount: 28000,
      deadline: DateTime(2027, 3, 31),
      emoji: '💻',
      monthlyContribution: 6500,
      contributionHistory: [
        SavingsContribution(date: DateTime(2026, 2, 15), amount: 8000),
        SavingsContribution(date: DateTime(2026, 3, 15), amount: 6500),
        SavingsContribution(date: DateTime(2026, 4, 15), amount: 7000),
        SavingsContribution(date: DateTime(2026, 5, 15), amount: 6500),
      ],
    ),
    SavingsGoalModel(
      id: 'goal_003',
      name: 'Trip to Pokhara',
      targetAmount: 15000,
      currentAmount: 8000,
      deadline: DateTime(2026, 8, 31),
      emoji: '🏔️',
      monthlyContribution: 2333,
      contributionHistory: [
        SavingsContribution(date: DateTime(2026, 4, 20), amount: 3000),
        SavingsContribution(date: DateTime(2026, 5, 20), amount: 5000),
      ],
    ),
  ];

  // Mock Nudges
  static List<NudgeModel> mockNudges = [
    NudgeModel(
      id: 'nudge_001',
      title: 'Shopping budget exceeded!',
      description: 'You\'ve spent NPR 4,300 of NPR 4,000 Shopping budget.',
      severity: NudgeSeverity.critical,
      date: DateTime.now().subtract(const Duration(hours: 2)),
      category: TransactionCategory.shopping,
    ),
    NudgeModel(
      id: 'nudge_002',
      title: 'Transport spending warning',
      description:
          'Transport spending at 70%. NPR 900 remaining for the month.',
      severity: NudgeSeverity.warning,
      date: DateTime.now().subtract(const Duration(days: 1)),
      category: TransactionCategory.transport,
    ),
    NudgeModel(
      id: 'nudge_003',
      title: 'Subscription check-in',
      description: 'Your monthly Worldlink payment was matched automatically.',
      severity: NudgeSeverity.info,
      date: DateTime.now().subtract(const Duration(days: 10)),
      category: TransactionCategory.utilities,
      isDismissed: true,
    ),
    NudgeModel(
      id: 'nudge_004',
      title: 'Savings milestone achieved',
      description:
          'Great job! You\'ve put aside NPR 5,000 for your Emergency Fund.',
      severity: NudgeSeverity.info,
      date: DateTime.now().subtract(const Duration(days: 15)),
      category: TransactionCategory.savings,
      isDismissed: true,
    ),
  ];

  // Financial Health Score constants
  static const int healthScoreValue = 72;
  static const Map<String, int> healthSubScores = {
    'budgetAdherence': 68,
    'savingsRate': 55,
    'consistency': 80,
    'diversity': 85,
  };

  // Mock Forecast Data (Actual days 1-15, Predicted days 16-30)
  static List<ForecastPoint> mockForecastData = [
    ForecastPoint(day: 1, amount: 800, isPrediction: false),
    ForecastPoint(day: 2, amount: 1650, isPrediction: false),
    ForecastPoint(day: 3, amount: 2350, isPrediction: false),
    ForecastPoint(day: 4, amount: 2400, isPrediction: false),
    ForecastPoint(day: 5, amount: 3370, isPrediction: false),
    ForecastPoint(day: 6, amount: 3500, isPrediction: false),
    ForecastPoint(day: 7, amount: 3500, isPrediction: false),
    ForecastPoint(
      day: 8,
      amount: 7800,
      isPrediction: false,
    ), // Daraz shopping + exam fee
    ForecastPoint(day: 9, amount: 7850, isPrediction: false),
    ForecastPoint(day: 10, amount: 9050, isPrediction: false), // Worldlink
    ForecastPoint(day: 11, amount: 9050, isPrediction: false),
    ForecastPoint(day: 12, amount: 10550, isPrediction: false), // Groceries
    ForecastPoint(day: 13, amount: 10550, isPrediction: false),
    ForecastPoint(
      day: 14,
      amount: 11750,
      isPrediction: false,
    ), // Momo + BhatBhateni
    ForecastPoint(day: 15, amount: 12750, isPrediction: false), // Petrol
    // Predictions
    ForecastPoint(day: 16, amount: 13800, isPrediction: true),
    ForecastPoint(day: 17, amount: 14800, isPrediction: true),
    ForecastPoint(
      day: 18,
      amount: 15600,
      isPrediction: true,
    ), // predicted book bookstore
    ForecastPoint(day: 19, amount: 16300, isPrediction: true),
    ForecastPoint(day: 20, amount: 17800, isPrediction: true), // predicted gym
    ForecastPoint(day: 21, amount: 18450, isPrediction: true), // today's state
    ForecastPoint(
      day: 22,
      amount: 19550,
      isPrediction: true,
    ), // predicted steam purchase
    ForecastPoint(day: 23, amount: 20500, isPrediction: true),
    ForecastPoint(day: 24, amount: 21000, isPrediction: true),
    ForecastPoint(
      day: 25,
      amount: 21700,
      isPrediction: true,
    ), // electricity predicted
    ForecastPoint(day: 26, amount: 22800, isPrediction: true),
    ForecastPoint(day: 27, amount: 23500, isPrediction: true),
    ForecastPoint(day: 28, amount: 24150, isPrediction: true),
    ForecastPoint(day: 29, amount: 25500, isPrediction: true),
    ForecastPoint(day: 30, amount: 27800, isPrediction: true),
  ];
}
