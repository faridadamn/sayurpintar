import 'package:dio/dio.dart';
import 'package:sayurpintar/core/network/api_client.dart';
import 'package:sayurpintar/core/network/api_endpoints.dart';

/// Repository handling all authentication API calls.
class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  /// Send OTP to the given phone number.
  Future<SendOTPResponse> sendOTP(String phone) async {
    final response = await _apiClient.dio.post(
      ApiEndpoints.sendOtp,
      data: {'phone': phone},
    );
    return SendOTPResponse.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Verify OTP and receive auth tokens.
  Future<AuthResponse> verifyOTP(String phone, String otp) async {
    final response = await _apiClient.dio.post(
      ApiEndpoints.verifyOtp,
      data: {'phone': phone, 'otp': otp},
    );
    return AuthResponse.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Set user role (first-time setup).
  Future<void> setRole(String role) async {
    await _apiClient.dio.post(
      ApiEndpoints.setRole,
      data: {'role': role},
    );
  }

  /// Refresh an expired access token.
  Future<TokenPair> refreshToken(String refreshToken) async {
    final response = await _apiClient.dio.post(
      ApiEndpoints.refreshToken,
      data: {'refresh_token': refreshToken},
    );
    return TokenPair.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Fetch the current user profile.
  Future<User> getProfile() async {
    final response = await _apiClient.dio.get(ApiEndpoints.profile);
    return User.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Update the current user's profile.
  Future<User> updateProfile({
    String? name,
    String? address,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (address != null) data['address'] = address;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;

    final response = await _apiClient.dio.put(
      ApiEndpoints.profile,
      data: data,
    );
    return User.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Log the user out on the server side.
  Future<void> logout() async {
    await _apiClient.dio.post(ApiEndpoints.logout);
  }
}

// ──────────────────────────────────────────────
// Response / domain models
// ──────────────────────────────────────────────

class SendOTPResponse {
  final String phone;
  final int expiresIn;
  final int? cooldown;

  SendOTPResponse({
    required this.phone,
    required this.expiresIn,
    this.cooldown,
  });

  factory SendOTPResponse.fromJson(Map<String, dynamic> json) {
    return SendOTPResponse(
      phone: json['phone'] as String,
      expiresIn: json['expires_in'] as int,
      cooldown: json['cooldown'] as int?,
    );
  }
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final User? user;
  final bool needsRole;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.user,
    required this.needsRole,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      needsRole: json['needs_role'] as bool? ?? false,
    );
  }
}

class TokenPair {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

class User {
  final String id;
  final String phone;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? address;
  final bool isVerified;

  User({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.address,
    required this.isVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      address: json['address'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'role': role,
      'avatar_url': avatarUrl,
      'address': address,
      'is_verified': isVerified,
    };
  }

  bool get isPedagang => role == 'pedagang';
  bool get isPelanggan => role == 'pelanggan';
}
