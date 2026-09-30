import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthState {
  const AuthState({
    required this.isInitializing,
    required this.isLoading,
    required this.token,
    required this.user,
    required this.errorMessage,
  });

  final bool isInitializing;
  final bool isLoading;
  final String? token;
  final UserModel? user;
  final String? errorMessage;

  bool get isAuthenticated => (token ?? '').isNotEmpty && user != null;

  factory AuthState.initial() {
    return const AuthState(
      isInitializing: true,
      isLoading: false,
      token: null,
      user: null,
      errorMessage: null,
    );
  }

  factory AuthState.unauthenticated() {
    return const AuthState(
      isInitializing: false,
      isLoading: false,
      token: null,
      user: null,
      errorMessage: null,
    );
  }

  AuthState copyWith({
    bool? isInitializing,
    bool? isLoading,
    String? token,
    UserModel? user,
    String? errorMessage,
    bool clearToken = false,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      isInitializing: isInitializing ?? this.isInitializing,
      isLoading: isLoading ?? this.isLoading,
      token: clearToken ? null : (token ?? this.token),
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends Notifier<AuthState> {
  static const _tokenKey = 'jwt_token';
  static const _profileKey = 'profile';
  bool _bootstrapped = false;

  ApiService get _api => ref.read(apiServiceProvider);

  @override
  AuthState build() {
    _api.setUnauthorizedHandler(logout);
    if (!_bootstrapped) {
      _bootstrapped = true;
      Future<void>.microtask(_restoreSession);
    }
    return AuthState.initial();
  }

  Future<void> _restoreSession() async {
    final storage = ref.read(secureStorageProvider);
    final token = await storage.read(key: _tokenKey);
    final savedProfile = await storage.read(key: _profileKey);

    if (token == null || token.isEmpty) {
      state = AuthState.unauthenticated();
      return;
    }

    state = state.copyWith(isInitializing: true, clearError: true);

    try {
      _api.setAuthToken(token);
      final user = await _api.getCurrentUser();
      if (user.role == 'admin') {
        await logout();
        return;
      }
      await storage.write(key: _profileKey, value: jsonEncode(user.toJson()));
      state = AuthState(
        isInitializing: false,
        isLoading: false,
        token: token,
        user: user,
        errorMessage: null,
      );
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 401) {
        await storage.delete(key: _tokenKey);
        await storage.delete(key: _profileKey);
        _api.setAuthToken(null);
        state = AuthState.unauthenticated();
        return;
      }
      if (savedProfile != null) {
        try {
          final user = UserModel.fromJson(jsonDecode(savedProfile) as Map<String, dynamic>);
          if (user.role != 'admin') {
            state = AuthState(
              isInitializing: false,
              isLoading: false,
              token: token,
              user: user,
              errorMessage: null,
            );
            return;
          }
        } catch (_) {}
      }
      await storage.delete(key: _tokenKey);
      await storage.delete(key: _profileKey);
      _api.setAuthToken(null);
      state = AuthState.unauthenticated();
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _profileKey);
    _api.setAuthToken(null);

    try {
      final token = await _api.login(email: email, password: password);
      _api.setAuthToken(token);
      final user = await _api.getCurrentUser();
      if (user.role == 'admin') {
        _api.setAuthToken(null);
        throw Exception('HUIT dành cho tài khoản nhân viên. Vui lòng dùng trang quản trị.');
      }
      await storage.write(key: _profileKey, value: jsonEncode(user.toJson()));
      await storage.write(key: _tokenKey, value: token);

      state = AuthState(
        isInitializing: false,
        isLoading: false,
        token: token,
        user: user,
        errorMessage: null,
      );
    } catch (error) {
      await storage.delete(key: _tokenKey);
      await storage.delete(key: _profileKey);
      _api.setAuthToken(null);
      state = state.copyWith(
        isInitializing: false,
        isLoading: false,
        errorMessage: _api.getError(error),
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final storage = ref.read(secureStorageProvider);

    await storage.delete(key: _tokenKey);
    await storage.delete(key: _profileKey);
    _api.setAuthToken(null);
    state = AuthState.unauthenticated();
  }

  Future<void> saveProfile(UserModel user) async {
    await ref.read(secureStorageProvider).write(
      key: _profileKey,
      value: jsonEncode(user.toJson()),
    );
    state = state.copyWith(user: user, clearError: true);
  }

}
