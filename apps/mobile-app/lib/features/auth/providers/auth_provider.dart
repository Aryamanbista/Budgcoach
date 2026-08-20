import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../shared/models/user_model.dart';
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
    bool clearUser = false,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
      user: clearUser ? null : user ?? this.user,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient apiClient;

  AuthNotifier(this.apiClient)
    : super(
        AuthState(
          isLoggedIn: false,
          isOnboardingCompleted: false,
          user: null,
          themeMode: ThemeMode.light,
        ),
      ) {
    _initAuth();
  }

  final _storage = const FlutterSecureStorage();

  Future<void> _initAuth() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token != null && token.isNotEmpty) {
        apiClient.setToken(token);
        debugPrint('AUTH: Found token on startup, attempting GET /me');
        final meResponse = await apiClient.dio.get('/me');
        final userData = meResponse.data;
        final realUser = UserModel(
          id: userData['id'],
          name: userData['full_name'] ?? 'User',
          email: userData['email'],
          occupation: userData['occupation']?.toString() ?? '',
          monthlyIncome:
              double.tryParse(userData['monthly_income']?.toString() ?? '') ??
              0,
        );
        state = state.copyWith(
          isLoggedIn: true,
          isOnboardingCompleted:
              true, // Assuming if they have token they are onboarded
          user: realUser,
        );
      }
    } catch (e) {
      debugPrint('AUTH: Init auth failed: $e');
      await _storage.delete(key: 'access_token');
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final response = await apiClient.dio.post(
        '/login',
        data: {'email': email.trim(), 'password': password},
      );
      final token = response.data['access_token'];
      if (token is! String || token.isEmpty) {
        throw const FormatException(
          'The server returned an invalid access token.',
        );
      }
      apiClient.setToken(token);
      await _storage.write(key: 'access_token', value: token);
      await _loadCurrentUser();
    } catch (e) {
      apiClient.clearToken();
      await _storage.delete(key: 'access_token');
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await apiClient.dio.post(
      '/register',
      data: {
        'full_name': name.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    await login(email: email, password: password);
  }

  Future<void> _loadCurrentUser() async {
    final meResponse = await apiClient.dio.get('/me');
    final userData = meResponse.data as Map<String, dynamic>;
    state = state.copyWith(
      isLoggedIn: true,
      user: UserModel(
        id: userData['id'].toString(),
        name: userData['full_name']?.toString() ?? 'User',
        email: userData['email'].toString(),
        occupation: userData['occupation']?.toString() ?? '',
        monthlyIncome:
            double.tryParse(userData['monthly_income']?.toString() ?? '') ?? 0,
      ),
    );
  }

  Future<void> completeOnboarding({
    required String name,
    required String occupation,
    required double monthlyIncome,
  }) async {
    final response = await apiClient.dio.patch(
      '/me',
      data: {
        'full_name': name.trim(),
        'occupation': occupation.trim(),
        'monthly_income': monthlyIncome,
      },
    );
    final userData = response.data as Map<String, dynamic>;
    final updatedUser = UserModel(
      id: userData['id'].toString(),
      name: userData['full_name']?.toString() ?? name,
      email: userData['email']?.toString() ?? state.user?.email ?? '',
      occupation: userData['occupation']?.toString() ?? occupation,
      monthlyIncome:
          double.tryParse(userData['monthly_income']?.toString() ?? '') ??
          monthlyIncome,
    );
    state = state.copyWith(
      isOnboardingCompleted: true,
      user: updatedUser,
      isLoggedIn: true,
    );
  }

  Future<void> updateMonthlyIncome(double amount) async {
    if (state.user != null) {
      await apiClient.dio.patch('/me', data: {'monthly_income': amount});
      final updatedUser = state.user!.copyWith(monthlyIncome: amount);
      state = state.copyWith(user: updatedUser);
    }
  }

  void toggleTheme() {
    state = state.copyWith(
      themeMode: state.themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light,
    );
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    apiClient.clearToken();
    state = state.copyWith(
      isLoggedIn: false,
      isOnboardingCompleted: false,
      clearUser: true,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
