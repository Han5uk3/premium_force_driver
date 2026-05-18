import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/apis.dart';
import 'package:premium_force_driver/models/driver.dart';
import 'package:premium_force_driver/services/notification_service.dart';
import 'package:premium_force_driver/storage/user_local_storage.dart';

enum AuthStatus {
  initial,
  loading,
  otpSent,
  otpVerified,
  authenticated,
  unauthenticated,
  failure,
}

/// Provider that manages the full authentication lifecycle for drivers.
///
/// Uses [ApiService] to communicate with the backend.
///
/// **Storage strategy**: Only `driverId` and `phoneNumber` are stored locally
/// in Hive. Full driver data is fetched from the backend via
/// `GET /api/drivers/:id` when needed (e.g. on app launch, after login).
///
/// OTP Flow:
/// 1. `requestOtp()` → calls `POST /api/drivers/send-otp`
/// 2. `verifyOtp()`  → calls `POST /api/drivers/verify-otp`
///    - If response contains `driver` → existing driver → [AuthStatus.authenticated]
/// 3. Driver can update profile via `updateDriver()`
class AuthProvider extends ChangeNotifier {
  static const int resendDuration = 60; // seconds

  final ApiService _api = ApiService();
  Timer? _resendTimer;

  AuthStatus _status = AuthStatus.initial;
  AuthStatus get status => _status;

  DriverModel? _driver;
  DriverModel? get driver => _driver;

  String? _phoneNumber;
  String? get phoneNumber => _phoneNumber;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _resendCountdown = 0;
  int get resendCountdown => _resendCountdown;

  bool _isOtpLoading = false;
  bool get isOtpLoading => _isOtpLoading;

  // ---------------------------------------------------------------------------
  // Timer helpers
  // ---------------------------------------------------------------------------

  void _startResendTimer() {
    _cancelResendTimer();
    _resendCountdown = resendDuration;
    notifyListeners();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _resendCountdown--;
      if (_resendCountdown <= 0) {
        timer.cancel();
      }
      notifyListeners();
    });
  }

  void _cancelResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = null;
  }

  @override
  void dispose() {
    _cancelResendTimer();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Fetch driver from backend
  // ---------------------------------------------------------------------------

  /// Fetch the full driver profile from the backend using [driverId].
  ///
  /// Calls `GET /api/drivers/:id`. Returns the [DriverModel] on success,
  /// or `null` if the driver was not found.
  /// Fetch the full driver profile from the backend using [driverId].
  ///
  /// Calls `GET /api/drivers/:id`. Returns the [DriverModel] on success,
  /// or `null` if the driver was not found or a network error occurred.
  Future<DriverModel?> fetchDriver({
    String? driverId,
    bool forceTokenRefresh = false,
  }) async {
    final id = driverId ?? UserLocalStorage.getUserId();
    if (id == null || id.isEmpty) {
      debugPrint('⚠️ Cannot fetch driver: no driverId stored');
      return null;
    }

    // Use ensureValidToken to handle auto-refresh if needed
    final token = await _api.ensureValidToken(forceRefresh: forceTokenRefresh);
    if (token == null) {
      debugPrint('⚠️ Cannot fetch driver: no valid token available');
      return null;
    }

    final result = await _api.getDriverById(id: id, token: token);
  
    if (result != null) {
      _driver = result;
      // Persist the full profile locally
      await UserLocalStorage.saveDriver(result.toJson());
      notifyListeners();
      debugPrint('✅ Fetched driver from backend: ${result.fullName}');
    } else {
      debugPrint('⚠️ Failed to fetch driver by id: $id');
    }
  
    return result;
  }

  // ---------------------------------------------------------------------------
  // Auth Check (for splash screen)
  // ---------------------------------------------------------------------------

  /// Check whether the driver is already logged in (e.g. on app start).
  ///
  /// Reads driverId + token from Hive. If they exist, fetches full driver
  /// data from the backend and sets [AuthStatus.authenticated].
  /// Check whether the driver is already logged in (e.g. on app start).
  ///
  /// Reads driverId from Hive. If it exists, attempts to fetch full driver
  /// data from the backend.
  Future<void> checkAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final storedDriverId = UserLocalStorage.getUserId();
      final hasToken = UserLocalStorage.getToken() != null;
      final cachedDriverJson = UserLocalStorage.getDriver();

      debugPrint(
        '🔍 Checking Auth: id=$storedDriverId, hasToken=$hasToken, hasCachedDriver=${cachedDriverJson != null}',
      );

      if (storedDriverId != null && storedDriverId.isNotEmpty) {
        // 1. Restore from cache first for immediate UI update
        if (cachedDriverJson != null) {
          try {
            _driver = DriverModel.fromJson(cachedDriverJson);
            _status = AuthStatus.authenticated;
            notifyListeners();
            debugPrint('📦 Restored driver from local cache: ${_driver!.fullName}');
          } catch (e) {
            debugPrint('⚠️ Failed to parse cached driver: $e');
          }
        }

        // 2. Refresh from backend (forcing token refresh as app just opened)
        final fetchedDriver = await fetchDriver(
          driverId: storedDriverId,
          forceTokenRefresh: true,
        );

        if (fetchedDriver != null) {
          _driver = fetchedDriver;
          _status = AuthStatus.authenticated;
          
          // Sync FCM token with backend after successful auth check if user is logged in
          unawaited(NotificationService.instance.syncTokenWithBackend());
          
          debugPrint('✅ Session refreshed from backend: ${fetchedDriver.fullName}');
        } else {
          // If fetch fails but we have cached data and a token, stay authenticated
          if (_driver != null && hasToken) {
            _status = AuthStatus.authenticated;
            debugPrint('⚠️ Backend fetch failed, staying authenticated with cached data');
          } else {
            _status = AuthStatus.unauthenticated;
            debugPrint('⚠️ Could not restore session — fetchDriver returned null and no usable cache');
          }
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Check Auth error: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // OTP - Send
  // ---------------------------------------------------------------------------

  /// Send an OTP to the provided phone number (Driver endpoint).
  ///
  /// Calls `POST /api/drivers/send-otp`.
  ///
  /// If the driver is registered by admin, OTP is sent.
  /// If the driver is not registered, an error is returned.
  ///
  /// Returns `true` if the OTP was sent successfully, `false` otherwise.
  Future<bool> requestOtp({
    required String countryCode,
    required String phoneNumber,
  }) async {
    _isOtpLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.sendOtp(
        countryCode: countryCode,
        phoneNumber: phoneNumber,
      );

      _isOtpLoading = false;

      if (result['success'] == true) {
        _startResendTimer();
        _status = AuthStatus.otpSent;
        _phoneNumber = phoneNumber;
        notifyListeners();
        return true;
      } else {
        // Check if this is a "not registered" error
        final message = (result['message'] as String? ?? '').toLowerCase();
        if (message.contains('not found') ||
            message.contains('not registered') ||
            message.contains('not exist') ||
            message.contains('driver') && message.contains('not')) {
          _errorMessage =
              'No driver registered with this phone number in the app';
        } else {
          _errorMessage = result['message'] as String? ?? 'Failed to send OTP';
        }
        _status = AuthStatus.failure;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Request OTP error: $e');
      _isOtpLoading = false;
      _errorMessage = 'Failed to send OTP. Please try again.';
      _status = AuthStatus.failure;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // OTP - Verify
  // ---------------------------------------------------------------------------

  /// Verify the OTP entered by the driver (Driver endpoint).
  ///
  /// Calls `POST /api/drivers/verify-otp`.
  ///
  /// Backend response contains:
  /// - `accessToken`, `refreshToken`
  /// - Driver data object
  ///
  /// If verification is successful:
  ///   → Save driverId + phoneNumber + tokens to Hive
  ///   → Fetch and store complete driver profile
  ///   → [AuthStatus.authenticated]
  Future<void> verifyOtp({
    required String otp,
    required String countryCode,
    required String phoneNumber,
  }) async {
    _isOtpLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.verifyOtp(
        countryCode: countryCode,
        phoneNumber: phoneNumber,
        otp: otp,
      );

      _isOtpLoading = false;
      _cancelResendTimer();

      if (result['success'] == true) {
        // --- Save tokens ---
        final data = result['data'] as Map<String, dynamic>?;
        final tokens =
            (result['tokens'] ?? data?['tokens'] ?? result) as Map<String, dynamic>?;

        final accessToken =
            (result['accessToken'] ?? tokens?['accessToken'] ?? result['token']) as String?;
        final refreshToken =
            (result['refreshToken'] ?? tokens?['refreshToken']) as String?;
        final rawExpiresIn = result['expiresIn'] ??
            tokens?['expiresIn'] ??
            result['expires_in'] ??
            tokens?['expires_in'];
        final expiresIn = rawExpiresIn != null
            ? int.tryParse(rawExpiresIn.toString())
            : null;

        if (accessToken != null && refreshToken != null) {
          await UserLocalStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiryDurationSeconds: expiresIn,
          );
        } else if (accessToken != null) {
          await UserLocalStorage.saveToken(accessToken);
        }

        // --- Check if driver data exists ---
        final driverData =
            result['driver'] ??
            data?['driver'] ??
            result['user'] ??
            result['data'];
        if (driverData != null && driverData is Map<String, dynamic>) {
          // Existing driver → save driver id + phoneNumber
          _driver = DriverModel.fromJson(driverData);
          final phone = driverData['phoneNumber'] ?? phoneNumber;

          await UserLocalStorage.saveUserCredentials(
            userId: _driver!.uid,
            phoneNumber: phone as String,
          );

          // Save the driver model locally
          await UserLocalStorage.saveDriver(_driver!.toJson());

          _status = AuthStatus.authenticated;
          _phoneNumber = phoneNumber;
          _resendCountdown = 0;
          debugPrint(
            '✅ Driver logged in: ${_driver!.fullName} (ID: ${_driver!.uid})',
          );
          
          // Sync FCM token with backend after successful login
          unawaited(NotificationService.instance.syncTokenWithBackend());
        } else {
          // No driver data found (should not happen for registered drivers)
          _errorMessage = 'Failed to fetch driver data';
          _status = AuthStatus.failure;
          debugPrint('❌ No driver data in OTP verification response');
        }

        notifyListeners();
      } else {
        _errorMessage =
            result['message'] as String? ?? 'OTP verification failed';
        _status = AuthStatus.failure;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Verify OTP error: $e');
      _isOtpLoading = false;
      _errorMessage = 'Verification failed. Please try again.';
      _status = AuthStatus.failure;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // OTP - Resend
  // ---------------------------------------------------------------------------

  /// Resend the OTP and restart the cooldown timer.
  Future<void> requestOtpResend({
    required String countryCode,
    required String phoneNumber,
  }) async {
    if (_resendCountdown > 0) return;

    final result = await _api.sendOtp(
      countryCode: countryCode,
      phoneNumber: phoneNumber,
    );

    if (result['success'] == true) {
      _startResendTimer();
      _status = AuthStatus.otpSent;
      _phoneNumber = phoneNumber;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Driver Registration
  // ---------------------------------------------------------------------------

  /// Register a new driver profile after OTP verification.
  ///
  /// Called during driver signup to create the complete driver account.
  Future<void> submitDriverRegistration({
    required String firstName,
    required String lastName,
    required String email,
    required String countryCode,
    required String phoneNumber,
    String? location,
    double? lat,
    double? long,
    String? licenseNumber,
    DateTime? licenseExpiry,
    File? profileImage,
    File? licenseImage,
  }) async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final token = UserLocalStorage.getToken();
      final result = await _api.registerDriver(
        firstName: firstName,
        lastName: lastName,
        email: email,
        countryCode: countryCode,
        phoneNumber: phoneNumber,
        location: location,
        lat: lat,
        long: long,
        licenseNumber: licenseNumber,
        licenseExpiry: licenseExpiry,
        profileImage: profileImage,
        licenseImage: licenseImage,
        token: token,
      );

      if (result['success'] == true) {
        final driverData = result['driver'] ?? result['data'] ?? result;
        if (driverData is Map<String, dynamic>) {
          _driver = DriverModel.fromJson(driverData);

          await UserLocalStorage.saveUserCredentials(
            userId: _driver!.uid,
            phoneNumber: phoneNumber,
          );

          // Save the driver model locally
          await UserLocalStorage.saveDriver(_driver!.toJson());
        }

        _status = AuthStatus.authenticated;
        
        // Sync FCM token with backend after successful registration
        unawaited(NotificationService.instance.syncTokenWithBackend());
        
        notifyListeners();
      } else {
        _status = AuthStatus.failure;
        _errorMessage = result['message'] as String? ?? 'Registration failed';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Submit Driver Registration error: $e');
      _status = AuthStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Update driver profile information.
  ///
  /// Can be called after registration to update driver details.
  Future<bool> updateDriverProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? location,
    double? lat,
    double? long,
    String? licenseNumber,
    DateTime? licenseExpiry,
    File? profileImage,
    File? licenseImage,
  }) async {
    final driverId = _driver?.uid;
    if (driverId == null) {
      _errorMessage = 'Driver ID not found';
      return false;
    }

    try {
      final token = UserLocalStorage.getToken();
      final result = await _api.updateDriver(
        id: driverId,
        firstName: firstName,
        lastName: lastName,
        email: email,
        location: location,
        lat: lat,
        long: long,
        licenseNumber: licenseNumber,
        licenseExpiry: licenseExpiry,
        profileImage: profileImage,
        licenseImage: licenseImage,
        token: token,
      );

      if (result['success'] == true) {
        final driverData = result['driver'] ?? result['data'];
        if (driverData is Map<String, dynamic>) {
          _driver = DriverModel.fromJson(driverData);
          await UserLocalStorage.saveDriver(_driver!.toJson());
          notifyListeners();
          return true;
        }
      } else {
        _errorMessage = result['message'] as String? ?? 'Update failed';
      }
      return false;
    } catch (e) {
      debugPrint('Update Driver Profile error: $e');
      _errorMessage = e.toString();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Token Refresh
  // ---------------------------------------------------------------------------

  /// Refresh the access token using the stored refresh token.
  Future<bool> refreshToken() async {
    final storedRefreshToken = UserLocalStorage.getRefreshToken();
    if (storedRefreshToken == null) return false;

    try {
      final result = await _api.refreshAccessToken(
        refreshToken: storedRefreshToken,
      );

      if (result['success'] == true) {
        final newAccess = result['accessToken'] as String?;
        final newRefresh = result['refreshToken'] as String?;

        if (newAccess != null && newRefresh != null) {
          await UserLocalStorage.saveTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
          );
        } else if (newAccess != null) {
          await UserLocalStorage.saveToken(newAccess);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

  /// Sign the driver out.
  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      // Delete the FCM token so this device stops receiving notifications
      // for the signed-out driver.
      await NotificationService.instance.deleteToken();

      // Clear local storage
      await UserLocalStorage.clearUser();

      _cancelResendTimer();
      _driver = null;
      _phoneNumber = null;
      _errorMessage = null;
      _resendCountdown = 0;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
      _status = AuthStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Fetch the latest driver profile details using the profile/me endpoint
  Future<DriverModel?> fetchDriverProfile() async {
    _isOtpLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _api.ensureValidToken();
      if (token == null) {
        _errorMessage = 'Session expired. Please login again.';
        _isOtpLoading = false;
        notifyListeners();
        return null;
      }

      final result = await _api.getDriverProfile();
      _isOtpLoading = false;

      if (result['success'] == true) {
        final driverData = result['driver'] ?? result['data'];
        if (driverData is Map<String, dynamic>) {
          _driver = DriverModel.fromJson(driverData);
          await UserLocalStorage.saveDriver(_driver!.toJson());
          notifyListeners();
          return _driver;
        }
      }
      
      _errorMessage = result['message'] as String? ?? 'Failed to fetch driver profile';
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Fetch driver profile error: $e');
      _isOtpLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Toggle driver work started status
  Future<bool> toggleWorkStatus(bool isWorkstarted) async {
    final driverId = _driver?.uid;
    if (driverId == null) {
      _errorMessage = 'Driver not logged in';
      return false;
    }

    try {
      final result = await _api.updateWorkStatus(
        id: driverId,
        isWorkstarted: isWorkstarted,
      );

      if (result['success'] == true) {
        // Re-fetch profile to sync all status fields
        await fetchDriverProfile();
        return true;
      } else {
        _errorMessage = result['message'] as String? ?? 'Failed to toggle availability';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Toggle work status error: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Take out a fleet vehicle
  Future<bool> takeOutFleet(String fleetId) async {
    _isOtpLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.takeOutFleet(fleetId);
      _isOtpLoading = false;

      if (result['success'] == true) {
        // Re-fetch profile to update hasActiveVehicle and activeVehicle fields
        await fetchDriverProfile();
        return true;
      } else {
        _errorMessage = result['message'] as String? ?? 'Failed to take out vehicle';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Take out fleet error: $e');
      _isOtpLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Return the active vehicle
  Future<bool> returnFleet() async {
    _isOtpLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.returnFleet();
      _isOtpLoading = false;

      if (result['success'] == true) {
        // Re-fetch profile to update hasActiveVehicle and activeVehicle fields
        await fetchDriverProfile();
        return true;
      } else {
        _errorMessage = result['message'] as String? ?? 'Failed to return vehicle';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Return fleet error: $e');
      _isOtpLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
