import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/api_logger.dart';
import 'package:premium_force_driver/models/user.dart';
import 'package:premium_force_driver/models/driver.dart';
import 'package:premium_force_driver/storage/user_local_storage.dart';

/// Centralised API service for the Premium Force app.
///
/// Uses [Dio] with a built-in logging interceptor for clear debugging.
///
/// Usage:
/// ```dart
/// final api = ApiService();
/// final result = await api.createUser(...);
/// ```
class ApiService {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Base URL of the AWS backend.
  static const String _baseUrl = 'https://api.premiumforcegroup.com/api/';

  // ---------------------------------------------------------------------------
  // Singleton + Dio instance
  // ---------------------------------------------------------------------------

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  Future<String?>? _refreshFuture;
  VoidCallback? onSessionExpired;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );

    // ── Global Interceptor for Auth + Token Refresh ──────
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          // Skip for auth endpoints if they don't need the header
          final path = options.path;
          if (path.contains('send-otp') ||
              path.contains('verify-otp') ||
              path.contains('refresh-token') ||
              path.contains('auth/google')) {
            return handler.next(options);
          }

          final token = UserLocalStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (e, handler) async {
          // If we get a 401 Unauthorized, try to refresh the token
          if (e.response?.statusCode == 401) {
            // Avoid infinite loop if refresh itself fails with 401
            if (e.requestOptions.path.contains('refresh-token')) {
              onSessionExpired?.call();
              return handler.next(e);
            }

            try {
              final newToken = await ensureValidToken();
              if (newToken != null) {
                // Update header and retry
                final options = e.requestOptions;
                options.headers['Authorization'] = 'Bearer $newToken';

                final response = await _dio.fetch(options);
                return handler.resolve(response);
              } else {
                onSessionExpired?.call();
              }
            } catch (retryError) {
              onSessionExpired?.call();
            }
          }
          return handler.next(e);
        },
      ),
    );

    // ── Logging interceptor (debug mode only) ──────────────
    if (kDebugMode) {
      _dio.interceptors.add(DriverApiLogger(label: 'api'));
    }
  }

  /// The preferred-language and push-token fields the auth endpoints accept.
  ///
  /// OTP verification and registration both take the same optional pair, and
  /// both treat a missing value as "leave unchanged" — so blank entries are
  /// dropped rather than sent empty. Once signed in, the same two fields are
  /// updated through `PATCH /api/drivers/settings`.
  static Map<String, String> _localePayload(String? locale, String? fcmToken) {
    final language = locale?.trim();
    final token = fcmToken?.trim();
    return {
      if (language != null && language.isNotEmpty) 'locale': language,
      if (token != null && token.isNotEmpty) 'fcmToken': token,
    };
  }

  /// Attach a Bearer token for authenticated requests.
  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  /// Ensure access token is valid and refresh if needed.
  ///
  /// Call this before making authenticated API requests.
  /// Returns the current (potentially refreshed) access token.
  /// Returns null if token refresh fails.
  Future<String?> ensureValidToken({bool forceRefresh = false}) async {
    // 1. If another refresh task is already running, wait for its result.
    if (_refreshFuture != null) {
      try {
        return await _refreshFuture;
      } catch (_) {
        return null;
      }
    }

    // 2. If token is still valid (not expiring soon) and no forceRefresh requested, return it.
    if (!forceRefresh && !UserLocalStorage.isTokenExpiredOrExpiring()) {
      final token = UserLocalStorage.getToken();
      if (token != null && token.isNotEmpty) {
        return token;
      }
    }

    // 3. Otherwise, start a new refresh task and cache its future.
    _refreshFuture = _refreshInternal();
    try {
      final newToken = await _refreshFuture;
      return newToken;
    } finally {
      _refreshFuture = null; // Clear so subsequent calls can run if needed.
    }
  }

  /// Internal implementation of token refresh.
  Future<String?> _refreshInternal() async {
    final refreshToken = UserLocalStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      onSessionExpired?.call();
      return null;
    }

    try {
      final result = await refreshAccessToken(refreshToken: refreshToken);

      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>?;

        final newAccessToken =
            (result['accessToken'] ?? data?['accessToken']) as String?;
        final newRefreshToken =
            (result['refreshToken'] ?? data?['refreshToken']) as String?;
        final rawExpiresIn =
            result['expiresIn'] ??
            data?['expiresIn'] ??
            result['expires_in'] ??
            data?['expires_in'];

        // Parse expiresIn if it's a number, or handle string like "1d"
        int? expiresIn;
        if (rawExpiresIn != null) {
          if (rawExpiresIn.toString().toLowerCase() == '1d') {
            expiresIn = 86400; // 24 hours in seconds
          } else {
            expiresIn = int.tryParse(rawExpiresIn.toString());
          }
        }

        if (newAccessToken != null) {
          await UserLocalStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken ?? refreshToken,
            expiryDurationSeconds: expiresIn,
          );
          return newAccessToken;
        }
      }

      onSessionExpired?.call();
      return null;
    } catch (e) {
      onSessionExpired?.call();
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Auth - OTP
  // ---------------------------------------------------------------------------

  /// Request an OTP for the given [phoneNumber] (Driver endpoint).
  ///
  /// Calls `POST /api/drivers/send-otp`.
  /// If the driver is not registered by admin, returns an error.
  Future<Map<String, dynamic>> sendOtp({
    required String countryCode,
    required String phoneNumber,
    String purpose = 'login',
  }) async {
    try {
      final response = await _dio.post(
        '/drivers/send-otp',
        data: {
          'countryCode': countryCode,
          'phoneNumber': phoneNumber,
          'purpose': purpose,
        },
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Verify the [otp] for the given [phoneNumber] (Driver endpoint).
  ///
  /// Calls `POST /api/drivers/verify-otp`.
  /// On success the backend returns:
  /// - `accessToken` / `refreshToken`
  /// - Driver data if already registered
  /// [locale] and [fcmToken] ride along so the backend can start addressing
  /// this driver in their language, and on this device, from the moment they
  /// log in.
  Future<Map<String, dynamic>> verifyOtp({
    required String countryCode,
    required String phoneNumber,
    required String otp,
    String purpose = 'login',
    String? locale,
    String? fcmToken,
  }) async {
    try {
      final response = await _dio.post(
        '/drivers/verify-otp',
        data: {
          'countryCode': countryCode,
          'phoneNumber': phoneNumber,
          'otp': otp,
          'purpose': purpose,
          ..._localePayload(locale, fcmToken),
        },
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Refresh the access token using a valid [refreshToken] (Driver endpoint).
  Future<Map<String, dynamic>> refreshAccessToken({
    required String refreshToken,
  }) async {
    try {
      final response = await _dio.post(
        '/drivers/refresh-token',
        data: {'refreshToken': refreshToken},
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Auth - Google Sign-In
  // ---------------------------------------------------------------------------

  /// Authenticate with Google.
  ///
  /// Sends the Google [idToken] along with platform type to the backend.
  /// The endpoint lives at `/auth/google` (outside the `/api` prefix).
  Future<Map<String, dynamic>> googleAuth({required String idToken}) async {
    try {
      final data = {'idToken': idToken};

      final response = await _dio.post(
        'http://54.252.191.113:5000/auth/google',
        data: data,
      );

      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // User Profile
  // ---------------------------------------------------------------------------

  /// Create a new user profile.
  ///
  /// Uses **multipart form-data** to match the backend's expected format.
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String email,
    required String countryCode,
    required String phoneNumber,
    String? location,
    double? lat,
    double? long,
    String? specialId,
    String role = 'customer',
    File? profileImage,
    String? token,
  }) async {
    try {
      final formData = FormData.fromMap({
        'username': username,
        'email': email,
        'countryCode': countryCode,
        'phoneNumber': phoneNumber,
        'role': role,
        'location': location,
        if (lat != null) 'lat': lat.toString(),
        if (long != null) 'long': long.toString(),
        if (specialId != null && specialId.isNotEmpty) 'specialId': specialId,
        if (profileImage != null)
          'profileImage': await MultipartFile.fromFile(
            profileImage.path,
            filename:
                '${username.replaceAll(' ', '_').toLowerCase()}_profile.${profileImage.path.split('.').last}',
          ),
      });

      final response = await _dio.post(
        '/users',
        data: formData,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch all users.
  Future<Map<String, dynamic>> getAllUsers({String? token}) async {
    try {
      final response = await _dio.get(
        '/users',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch a single user by [id] (MongoDB ObjectId).
  ///
  /// Returns a [UserModel] on success, or `null` if not found.
  Future<UserModel?> getUserById({required String id, String? token}) async {
    try {
      final response = await _dio.get(
        '/users/$id',
        options: token != null ? _authOptions(token) : null,
      );
      final data = _success(response);
      if (data['success'] == true) {
        final userData = data['user'] ?? data['data'] ?? data;
        if (userData is Map<String, dynamic> &&
            userData.containsKey('username')) {
          return UserModel.fromJson(userData);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update an existing user profile.
  ///
  /// Uses **multipart form-data** to support optional image updates.
  Future<Map<String, dynamic>> updateUser({
    required String id,
    String? username,
    String? email,
    String? countryCode,
    String? phoneNumber,
    String? location,
    double? lat,
    double? long,
    String? specialId,
    String? role,
    File? profileImage,
    String? token,
  }) async {
    try {
      final fields = <String, dynamic>{};
      if (username != null) fields['username'] = username;
      if (email != null) fields['email'] = email;
      if (countryCode != null) fields['countryCode'] = countryCode;
      if (phoneNumber != null) fields['phoneNumber'] = phoneNumber;
      if (location != null) fields['location'] = location;
      if (lat != null) fields['lat'] = lat.toString();
      if (long != null) fields['long'] = long.toString();
      if (specialId != null) fields['specialId'] = specialId;
      if (role != null) fields['role'] = role;
      if (profileImage != null) {
        final name = (username ?? 'user').replaceAll(' ', '_').toLowerCase();
        fields['profileImage'] = await MultipartFile.fromFile(
          profileImage.path,
          filename: '${name}_profile.${profileImage.path.split('.').last}',
        );
      }

      final response = await _dio.put(
        '/users/$id',
        data: FormData.fromMap(fields),
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Delete a user by [id].
  Future<Map<String, dynamic>> deleteUser({
    required String id,
    String? token,
  }) async {
    try {
      final response = await _dio.delete(
        '/users/$id',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Driver Profile
  // ---------------------------------------------------------------------------

  /// Fetch a single driver by [id] (MongoDB ObjectId).
  ///
  /// Returns a [DriverModel] on success, or `null` if not found.
  /// This is the main method used to fetch driver data after OTP verification.
  Future<DriverModel?> getDriverById({
    required String id,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        '/drivers/$id',
        options: token != null ? _authOptions(token) : null,
      );
      final data = _success(response);
      if (data['success'] == true) {
        final driverData = data['driver'] ?? data['data'] ?? data;
        if (driverData is Map<String, dynamic>) {
          return DriverModel.fromJson(driverData);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch driver profile details.
  /// Calls `GET /api/drivers/profile/me`.
  Future<Map<String, dynamic>> getDriverProfile() async {
    try {
      final response = await _dio.get('/drivers/profile/me');
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Toggle driver work started status.
  /// Calls `PATCH /api/drivers/work-status`.
  Future<Map<String, dynamic>> updateWorkStatus({
    String? id,
    required bool isWorkstarted,
    String? token,
  }) async {
    try {
      final authToken = token ?? await ensureValidToken();
      final response = await _dio.patch(
        '/drivers/work-status',
        options: authToken != null ? _authOptions(authToken) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get list of fleets available for takeout.
  /// Calls `GET /api/fleets/list/driver`.
  Future<Map<String, dynamic>> getAvailableFleets() async {
    try {
      final response = await _dio.get('/fleets/list/driver');
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fleet take-out.
  /// Calls `POST /api/fleets/take-out` with fleetID in body.
  Future<Map<String, dynamic>> takeOutFleet(String fleetId) async {
    try {
      final response = await _dio.post(
        '/fleets/take-out',
        data: {'fleetID': fleetId},
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fleet return.
  /// Calls `POST /api/fleets/return`.
  Future<Map<String, dynamic>> returnFleet() async {
    try {
      // Pass an empty JSON object so the backend doesn't hang waiting for a body
      final response = await _dio.post('/fleets/return', data: {});
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch all drivers (Admin endpoint).
  Future<Map<String, dynamic>> getAllDrivers({String? token}) async {
    try {
      final response = await _dio.get(
        '/drivers/all',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Register a new driver (creates driver account).
  ///
  /// Uses **multipart form-data** to support profile image upload.
  /// Call this after OTP verification for new drivers.
  Future<Map<String, dynamic>> registerDriver({
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
    String? token,
    String? locale,
    String? fcmToken,
  }) async {
    try {
      final fields = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'driverName': '$firstName $lastName'.trim(),
        'email': email,
        'countryCode': countryCode,
        'phoneNumber': phoneNumber,
        'location': location,
        ..._localePayload(locale, fcmToken),
        if (lat != null) 'lat': lat.toString(),
        if (long != null) 'long': long.toString(),
        'licenseNumber': licenseNumber,
        if (licenseExpiry != null)
          'licenseExpiry': licenseExpiry.toIso8601String(),
      };

      if (profileImage != null) {
        final name = '${firstName.toLowerCase()}_${lastName.toLowerCase()}'
            .replaceAll(' ', '_');
        fields['profileImage'] = await MultipartFile.fromFile(
          profileImage.path,
          filename: '${name}_profile.${profileImage.path.split('.').last}',
        );
      }

      if (licenseImage != null) {
        final name = '${firstName.toLowerCase()}_${lastName.toLowerCase()}'
            .replaceAll(' ', '_');
        fields['licenseImage'] = await MultipartFile.fromFile(
          licenseImage.path,
          filename: '${name}_license.${licenseImage.path.split('.').last}',
        );
      }

      final response = await _dio.post(
        '/drivers/register',
        data: FormData.fromMap(fields),
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Update an existing driver profile.
  ///
  /// Uses **multipart form-data** to support optional image updates.
  Future<Map<String, dynamic>> updateDriver({
    required String id,
    String? firstName,
    String? lastName,
    String? email,
    String? countryCode,
    String? phoneNumber,
    String? location,
    double? lat,
    double? long,
    String? licenseNumber,
    DateTime? licenseExpiry,
    File? profileImage,
    File? licenseImage,
    String? token,
  }) async {
    try {
      final fields = <String, dynamic>{};
      if (firstName != null || lastName != null) {
        fields['driverName'] = '${firstName ?? ''} ${lastName ?? ''}'.trim();
      }
      if (firstName != null) fields['firstName'] = firstName;
      if (lastName != null) fields['lastName'] = lastName;
      if (email != null) fields['email'] = email;
      if (countryCode != null) fields['countryCode'] = countryCode;
      if (phoneNumber != null) fields['phoneNumber'] = phoneNumber;
      if (location != null) fields['location'] = location;
      if (lat != null) fields['lat'] = lat.toString();
      if (long != null) fields['long'] = long.toString();
      if (licenseNumber != null) fields['licenseNumber'] = licenseNumber;
      if (licenseExpiry != null) {
        fields['licenseExpiry'] = licenseExpiry.toIso8601String();
      }

      if (profileImage != null) {
        final name = '${firstName?.toLowerCase() ?? 'driver'}_profile'
            .replaceAll(' ', '_');
        fields['profileImage'] = await MultipartFile.fromFile(
          profileImage.path,
          filename: '$name.${profileImage.path.split('.').last}',
        );
      }

      if (licenseImage != null) {
        final name = '${firstName?.toLowerCase() ?? 'driver'}_license'
            .replaceAll(' ', '_');
        fields['licenseImage'] = await MultipartFile.fromFile(
          licenseImage.path,
          filename: '$name.${licenseImage.path.split('.').last}',
        );
      }

      final response = await _dio.put(
        '/drivers/$id',
        data: FormData.fromMap(fields),
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Update the driver's profile image.
  /// Calls `PATCH /api/drivers/profile/profile-image` with form-data.
  Future<Map<String, dynamic>> updateProfileImage({
    required File profileImage,
    String? token,
  }) async {
    try {
      final filename = profileImage.path.split('/').last;
      final formData = FormData.fromMap({
        'profileImage': await MultipartFile.fromFile(
          profileImage.path,
          filename: filename,
        ),
      });

      final response = await _dio.patch(
        '/drivers/profile/profile-image',
        data: formData,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Delete a driver by [id].
  Future<Map<String, dynamic>> deleteDriver({
    required String id,
    String? token,
  }) async {
    try {
      final response = await _dio.delete(
        '/drivers/$id',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch monthly earnings for the driver.
  ///
  /// Calls `GET /api/bookings/earnings/monthly?year={year}`.
  Future<Map<String, dynamic>> getMonthlyEarnings({
    required int year,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        '/bookings/earnings/monthly?year=$year',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch hourly rate for a specific vehicle and hour count.
  ///
  /// Calls `GET /api/hourly-routes/city-to-city/filter`.
  /// Used to determine extra hour price by passing `hour = 999`.
  /// Fetch all hourly rates for a specific vehicle.
  /// Calls `GET /api/hourly-routes/vehicle/{vehicleId}`.
  Future<Map<String, dynamic>> getHourlyRate({
    required String? vehicleId,
    String? token,
  }) async {
    try {
      if (vehicleId == null) {
        return {'success': false, 'message': 'Vehicle ID is required'};
      }

      final authToken = token ?? await ensureValidToken();
      final response = await _dio.get(
        '/hourly-routes/vehicle/$vehicleId',
        options: authToken != null ? _authOptions(authToken) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // FCM / Push Notifications
  // ---------------------------------------------------------------------------

  /// Register or update the [fcmToken] for the user identified by [userId].
  ///
  /// Call this after login / signup once you have both a valid user id and an
  /// FCM token.
  /// Register or update the [fcmToken] for the driver identified by [driverId].
  ///
  /// Call this after login / signup once you have both a valid driver id and an
  /// FCM token.
  Future<Map<String, dynamic>> updateFcmToken({
    String? userid,
    required String fcmToken,
    String? token,
  }) async {
    try {
      final response = await _dio.patch(
        '/drivers/fcm-token',
        data: {'fcmToken': fcmToken},
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Response helpers
  // ---------------------------------------------------------------------------

  /// Extract a success map from a Dio [Response].
  Map<String, dynamic> _success(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return {'success': true, ...data};
    }
    return {'success': true, 'data': data};
  }

  /// Convert any error into a consistent map.
  Map<String, dynamic> _handleError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;

      String message;
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'Request timed out. Please try again.';
        case DioExceptionType.connectionError:
          message = 'No internet connection. Please check your network.';
        case DioExceptionType.badResponse:
          message =
              (data is Map<String, dynamic> ? data['message'] : null)
                  as String? ??
              'Server error ($statusCode)';
        case DioExceptionType.cancel:
          message = 'Request was cancelled.';
        default:
          message = 'Something went wrong. Please try again.';
      }

      return {
        'success': false,
        'statusCode': statusCode,
        'message': message,
        if (data is Map<String, dynamic>) ...data,
      };
    }

    return {
      'success': false,
      'message': 'Something went wrong. Please try again.',
    };
  }
}
