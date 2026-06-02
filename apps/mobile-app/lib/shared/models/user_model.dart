class UserModel {
  final String id;
  final String name;
  final String email;
  final String occupation;
  final double monthlyIncome;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.occupation,
    required this.monthlyIncome,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? occupation,
    double? monthlyIncome,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      occupation: occupation ?? this.occupation,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
    );
  }
}
