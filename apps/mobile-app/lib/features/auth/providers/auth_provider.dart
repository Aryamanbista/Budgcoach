import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/network/api_client.dart';

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
  final ApiClient apiClient;
  
  AuthNotifier(this.apiClient)
      : super(AuthState(
          isLoggedIn: false,
          isOnboardingCompleted: false,
          user: MockData.mockUser,
          themeMode: ThemeMode.light,
        ));

  Future<void> login() async {
    try {
      // Attempt login first
      Response response;
      try {
        response = await apiClient.dio.post('/login', data: {
          'email': 'test@example.com',
          'password': 'password'
        });
      } on DioException catch (e) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 404) {
          // If user doesn't exist or unauthorized, register them first
          await apiClient.dio.post('/register', data: {
            'email': 'test@example.com',
            'password': 'password',
            'full_name': 'Test User'
          });
          // Then login again
          response = await apiClient.dio.post('/login', data: {
            'email': 'test@example.com',
            'password': 'password'
          });
        } else {
          rethrow;
        }
      }

      final token = response.data['access_token'];
      apiClient.setToken(token);

      state = state.copyWith(
        isLoggedIn: true,
        user: MockData.mockUser,
      );
    } catch (e) {
      debugPrint('Seamless login failed: $e');
    }
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
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
