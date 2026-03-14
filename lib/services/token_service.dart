import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/apis.dart';
import 'package:premium_force_driver/storage/user_local_storage.dart';

/// Service for managing token refresh and expiry.
///
/// Automatically refreshes access tokens when they expire or are about to expire.
/// Handles token refresh errors gracefully.
class TokenService {
  static final TokenService _instance = TokenService._internal();

  factory TokenService() => _instance;

  TokenService._internal();

  final ApiService _apiService = ApiService();
  bool _isRefreshing = false;

  /// Ensure the access token is valid and refresh if needed.
  ///
  /// Should be called before making authenticated API requests.
  /// Returns true if token is valid (either was valid or was successfully refreshed).
  /// Returns false if token cannot be refreshed.
  Future<bool> ensureValidToken() async {
    // If token is still valid, no action needed
    if (!UserLocalStorage.isTokenExpiredOrExpiring()) {
      return true;
    }

    // If already refreshing, wait a bit and try again
    if (_isRefreshing) {
      await Future.delayed(const Duration(seconds: 1));
      return ensureValidToken();
    }

    // Attempt to refresh token
    return _refreshToken();
  }

  /// Refresh the access token using the refresh token.
  ///
  /// Returns true if refresh was successful.
  /// Returns false if refresh failed (user needs to re-login).
  Future<bool> _refreshToken() async {
    _isRefreshing = true;

    try {
      final refreshToken = UserLocalStorage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('❌ Token Refresh │ No refresh token available');
        _isRefreshing = false;
        return false;
      }

      debugPrint('🔄 Token Refresh │ Refreshing access token...');

      final result = await _apiService.refreshAccessToken(
        refreshToken: refreshToken,
      );

      if (result['success'] == true) {
        final newAccessToken = result['accessToken'] as String?;
        final newRefreshToken = result['refreshToken'] as String?;
        final expiresIn = result['expiresIn'] as int?;

        if (newAccessToken != null) {
          await UserLocalStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken ?? refreshToken,
            expiryDurationSeconds: expiresIn ?? 3600,
          );

          debugPrint('✅ Token Refresh │ Token refreshed successfully');
          _isRefreshing = false;
          return true;
        } else {
          debugPrint('❌ Token Refresh │ No access token in refresh response');
          _isRefreshing = false;
          return false;
        }
      } else {
        debugPrint('❌ Token Refresh │ Failed: ${result['message']}');
        _isRefreshing = false;
        return false;
      }
    } catch (e) {
      debugPrint('❌ Token Refresh │ Error: $e');
      _isRefreshing = false;
      return false;
    }
  }

  /// Get debug info about current token status.
  String getTokenDebugInfo() {
    final remaining = UserLocalStorage.getTokenTimeRemaining();
    final isExpired = UserLocalStorage.isTokenExpiredOrExpiring();
    return 'Token: ${isExpired ? "EXPIRED" : "VALID"} (${remaining}s remaining)';
  }
}
