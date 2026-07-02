import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/mock/mock_data.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isOnboardingCompleted;
  final UserModel? user;
  final ThemeMode themeMode;

  AuthState({
    required this.isLoggedIn,
    required this.isOnboardingCompleted,
    required this.user,
    required this.themeMode,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isOnboardingCompleted,
    UserModel? user,
    ThemeMode? themeMode,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
      user: user ?? this.user,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier()
      : super(AuthState(
          isLoggedIn: false,
          isOnboardingCompleted: false,
          user: MockData.mockUser,
          themeMode: ThemeMode.light,
        ));

  void login() {
    state = state.copyWith(
      isLoggedIn: true,
      user: MockData.mockUser,
    );
  }

  void completeOnboarding({
    required String name,
    required String occupation,
    required double monthlyIncome,
  }) {
    final updatedUser = UserModel(
      id: 'user_mock_001',
      name: name,
      email: state.user?.email ?? 'aryaman@example.com',
      occupation: occupation,
      monthlyIncome: monthlyIncome,
    );
    MockData.mockUser = updatedUser; // Update mock data store
    state = state.copyWith(
      isOnboardingCompleted: true,
      user: updatedUser,
      isLoggedIn: true,
    );
  }

  void updateMonthlyIncome(double amount) {
    if (state.user != null) {
      final updatedUser = state.user!.copyWith(monthlyIncome: amount);
      MockData.mockUser = updatedUser;
      state = state.copyWith(user: updatedUser);
    }
  }

  void toggleTheme() {
    state = state.copyWith(
      themeMode: state.themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
    );
  }

  void logout() {
    state = state.copyWith(
      isLoggedIn: false,
      isOnboardingCompleted: false,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
