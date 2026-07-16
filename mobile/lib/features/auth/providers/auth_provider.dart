import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/features/auth/data/auth_repository.dart';
import 'package:sayurpintar/features/auth/data/auth_local_storage.dart';

// ──────────────────────────────────────────────
// Auth state
// ──────────────────────────────────────────────

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  needsRole,
  error,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get needsRole => status == AuthStatus.needsRole;
  bool get isError => status == AuthStatus.error;
}

// ──────────────────────────────────────────────
// Auth notifier
// ──────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final AuthLocalStorage _localStorage;

  AuthNotifier(this._repository, this._localStorage)
      : super(const AuthState()) {
    _checkAuthStatus();
  }

  User? get currentUser => _localStorage.user;
  bool get isLoggedIn => _localStorage.isLoggedIn;

  Future<void> _checkAuthStatus() async {
    if (_localStorage.isLoggedIn) {
      try {
        final user = await _repository.getProfile();
        await _localStorage.saveUser(user);
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } catch (e) {
        await _localStorage.clearAll();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<SendOTPResponse> sendOTP(String phone) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _repository.sendOTP(phone);
      await _localStorage.savePhone(phone);
      state = state.copyWith(status: AuthStatus.initial);
      return response;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _extractError(e),
      );
      rethrow;
    }
  }

  Future<void> verifyOTP(String phone, String otp) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _repository.verifyOTP(phone, otp);
      await _localStorage.saveTokens(
        response.accessToken,
        response.refreshToken,
      );
      if (response.user != null) {
        await _localStorage.saveUser(response.user!);
      }
      state = AuthState(
        status: response.needsRole
            ? AuthStatus.needsRole
            : AuthStatus.authenticated,
        user: response.user,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _extractError(e),
      );
      rethrow;
    }
  }

  Future<void> setRole(String role) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repository.setRole(role);
      final user = await _repository.getProfile();
      await _localStorage.saveUser(user);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _extractError(e),
      );
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? name,
    String? address,
    String? avatarUrl,
  }) async {
    try {
      final user = await _repository.updateProfile(
        name: name,
        address: address,
        avatarUrl: avatarUrl,
      );
      await _localStorage.saveUser(user);
      state = state.copyWith(user: user);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {
      // Ignore server-side errors on logout
    }
    await _localStorage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _extractError(Object e) {
    if (e is Exception) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    return 'Terjadi kesalahan. Coba lagi.';
  }
}

// ──────────────────────────────────────────────
// Providers
// ──────────────────────────────────────────────

final authLocalStorageProvider = Provider<AuthLocalStorage>((ref) {
  throw UnimplementedError(
    'AuthLocalStorage must be overridden in main.dart with SharedPreferences',
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ApiClient());
});

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(authLocalStorageProvider),
  );
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.read(authProvider.notifier).currentUser;
});
