import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/models/user.dart';
import 'package:premium_force_driver/models/driver.dart';
import 'package:premium_force_driver/models/booking.dart';
import 'package:premium_force_driver/models/review.dart';
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
            debugPrint('🌐 API │ 401 detected on ${e.requestOptions.path}');
            
            // Avoid infinite loop if refresh itself fails with 401
            if (e.requestOptions.path.contains('refresh-token')) {
              return handler.next(e);
            }

            try {
              final newToken = await ensureValidToken();
              if (newToken != null) {
                debugPrint('🌐 API │ Token refreshed successfully, retrying original request...');
                
                // Update header and retry
                final options = e.requestOptions;
                options.headers['Authorization'] = 'Bearer $newToken';
                
                final response = await _dio.fetch(options);
                return handler.resolve(response);
              }
            } catch (retryError) {
              debugPrint('🌐 API │ Global retry failed: $retryError');
            }
          }
          return handler.next(e);
        },
      ),
    );

    // ── Logging interceptor (debug mode only) ──────────────
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint('🌐 API │ $obj'),
        ),
      );
    }
  }

  /// Attach a Bearer token for authenticated requests.
  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  /// Ensure access token is valid and refresh if needed.
  ///
  /// Call this before making authenticated API requests.
  /// Returns the current (potentially refreshed) access token.
  /// Returns null if token refresh fails.
  Future<String?> ensureValidToken() async {
    // 1. If another refresh task is already running, wait for its result.
    if (_refreshFuture != null) {
      debugPrint('🔄 Token Service │ Waiting for existing refresh task...');
      try {
        return await _refreshFuture;
      } catch (_) {
        return null;
      }
    }

    // 2. If token is still valid (not expiring soon), return it immediately.
    if (!UserLocalStorage.isTokenExpiredOrExpiring()) {
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
      debugPrint('❌ Token Service │ Cannot refresh: no refresh token stored');
      return null;
    }

    try {
      debugPrint('🔄 Token Service │ Auto-refreshing access token...');
      final result = await refreshAccessToken(refreshToken: refreshToken);

      if (result['success'] == true) {
        final newAccessToken = result['accessToken'] as String?;
        final newRefreshToken = result['refreshToken'] as String?;
        final rawExpiresIn = result['expiresIn'];
        final expiresIn = rawExpiresIn != null
            ? int.tryParse(rawExpiresIn.toString())
            : null;

        if (newAccessToken != null) {
          await UserLocalStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken ?? refreshToken,
            expiryDurationSeconds: expiresIn,
          );
          debugPrint('✅ Token Service │ Access token refreshed successfully');
          return newAccessToken;
        }
      }

      debugPrint('❌ Token Service │ Failed to refresh token: ${result['message']}');
      return null;
    } catch (e) {
      debugPrint('❌ Token Service │ Error: $e');
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
  Future<Map<String, dynamic>> verifyOtp({
    required String countryCode,
    required String phoneNumber,
    required String otp,
    String purpose = 'login',
  }) async {
    try {
      final response = await _dio.post(
        '/drivers/verify-otp',
        data: {
          'countryCode': countryCode,
          'phoneNumber': phoneNumber,
          'otp': otp,
          'purpose': purpose,
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
        'drivers/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(
          headers: {
            'Authorization': 'Bearer $refreshToken',
          },
        ),
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

      debugPrint('🔐 Google Auth │ Sending data: $data');

      final response = await _dio.post(
        'http://54.252.191.113:5000/auth/google',
        data: data,
      );

      debugPrint('🔐 Google Auth │ Response: ${response.data}');

      return _success(response);
    } catch (e) {
      debugPrint('🔐 Google Auth │ Error: $e');
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
      debugPrint('getUserById error: $e');
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
      debugPrint('getDriverById error: $e');
      return null;
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

  // ---------------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------------

  /// Fetch all bookings assigned to the driver by [driverId].
  ///
  /// Calls `GET /api/bookings/driver/{driverId}`.
  /// Returns a list of BookingModel objects.
  Future<List<BookingModel>> getBookingsByDriverId({
    required String driverId,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        '/bookings/driver/$driverId',
        options: token != null ? _authOptions(token) : null,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> rawList = [];

        if (data is Map<String, dynamic>) {
          // Check common keys for list data
          final possibleKeys = ['bookings', 'data', 'result', 'results'];
          for (var key in possibleKeys) {
            if (data.containsKey(key) && data[key] is List) {
              rawList = data[key];
              break;
            }
          }
          // If no key found but it's a map, maybe the map itself is the object (not likely for 'all')
        } else if (data is List) {
          rawList = data;
        }

        return rawList.map((b) {
          try {
            if (b is Map<String, dynamic>) {
              return BookingModel.fromJson(b);
            }
            return null;
          } catch (e) {
            debugPrint('⚠️ Model Error │ Failed to parse regular booking: $e');
            return null;
          }
        }).whereType<BookingModel>().toList();
      }
      return [];
    } catch (e) {
      debugPrint('getBookingsByDriverId error: $e');
      return [];
    }
  }

  /// Fetch all hourly bookings assigned to the driver by [driverId].
  ///
  /// Calls `GET /api/hourly-bookings/driver/{driverId}`.
  Future<List<BookingModel>> getHourlyBookingsByDriverId({
    required String driverId,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        '/hourly-bookings/driver/$driverId',
        options: token != null ? _authOptions(token) : null,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> rawList = [];

        if (data is Map<String, dynamic>) {
          final possibleKeys = ['bookings', 'data', 'result', 'results'];
          for (var key in possibleKeys) {
            if (data.containsKey(key) && data[key] is List) {
              rawList = data[key];
              break;
            }
          }
        } else if (data is List) {
          rawList = data;
        }

        return rawList.map((b) {
          try {
            if (b is Map<String, dynamic>) {
              return BookingModel.fromJson(b);
            }
            return null;
          } catch (e) {
            debugPrint('⚠️ Model Error │ Failed to parse hourly booking: $e');
            return null;
          }
        }).whereType<BookingModel>().toList();
      }
      return [];
    } catch (e) {
      debugPrint('getHourlyBookingsByDriverId error: $e');
      return [];
    }
  }

  /// Fetch a single booking by [bookingId].
  ///
  /// Calls `GET /api/bookings/{bookingId}`.
  Future<BookingModel?> getBookingById({
    required String bookingId,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        '/bookings/$bookingId',
        options: token != null ? _authOptions(token) : null,
      );

      if (response.statusCode == 200) {
        return BookingModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('getBookingById error: $e');
      return null;
    }
  }

  /// Accept a booking by [bookingId].
  ///
  /// Calls `PATCH /api/bookings/{bookingId}/status` or `/api/hourly-bookings/{bookingId}/status` to update status to "AC" (Accepted).
  Future<Map<String, dynamic>> acceptBooking({
    required String bookingId,
    bool isHourly = false,
    String? token,
  }) async {
    try {
      final path = isHourly ? '/hourly-bookings/$bookingId/status' : '/bookings/$bookingId/status';
      final response = await _dio.patch(
        path,
        data: {'bookingID': bookingId, 'status': 'AC'}, // AC = Accepted
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Update booking status.
  ///
  /// Calls `PATCH /api/bookings/{bookingId}/status` or `/api/hourly-bookings/{bookingId}/status`.
  Future<Map<String, dynamic>> updateBookingStatus({
    required String bookingId,
    required String status,
    Map<String, dynamic> extraData = const {},
    bool isHourly = false,
    String? token,
  }) async {
    try {
      if (isHourly) {
        return await updateHourlyBooking(
          bookingId: bookingId,
          token: token,
          data: {
            ...extraData,
            'bookingStatus': status,
          },
        );
      } else {
        final response = await _dio.patch(
          '/bookings/$bookingId/status',
          data: {'bookingID': bookingId, 'status': status},
          options: token != null ? _authOptions(token) : null,
        );
        return _success(response);
      }
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Reject a booking by [bookingId].
  ///
  /// Calls `PATCH /api/bookings/{bookingId}/status` or `/api/hourly-bookings/{bookingId}/status` to update status to "CA" (Cancelled).
  Future<Map<String, dynamic>> rejectBooking({
    required String bookingId,
    bool isHourly = false,
    String? token,
  }) async {
    try {
      final path = isHourly ? '/hourly-bookings/$bookingId/status' : '/bookings/$bookingId/status';
      final response = await _dio.patch(
        path,
        data: {'bookingID': bookingId, 'status': 'CA'}, // CA = Cancelled
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Save chauffeur trip timing data (startTime, stopTime, duration) to backend.
  ///
  /// Calls `PUT /api/hourly-bookings/{bookingId}` with timing fields.
  /// [extraHours] is > 0 when the driver ran over the booked hour allocation.
  /// Update hourly booking data using PUT method.
  Future<Map<String, dynamic>> updateHourlyBooking({
    required String bookingId,
    required Map<String, dynamic> data,
    String? token,
  }) async {
    try {
      final authToken = token ?? await ensureValidToken();
      // Ensure the bookingID is in the body if the backend requires it
      data['bookingID'] = bookingId;
      data['bookingId'] = bookingId;

      final response = await _dio.put(
        '/hourly-bookings/$bookingId',
        data: data,
        options: authToken != null ? _authOptions(authToken) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Start tracking a booking.
  ///
  /// Calls `POST /api/drivers/complete-booking/tracking` or `/HourlyBooking`.
  Future<Map<String, dynamic>> startTrackingBooking({
    required String bookingId,
    bool isHourly = false,
    String? token,
  }) async {
    try {
      final path = isHourly
          ? '/drivers/complete-booking/tracking/HourlyBooking'
          : '/drivers/complete-booking/tracking';
      final response = await _dio.post(
        path,
        data: {
          'bookingID': bookingId,
        },
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Mark a booking as completed (trip finished).
  ///
  /// Calls `POST /api/drivers/complete-trip/` endpoint.
  Future<Map<String, dynamic>> completeBooking({
    required String bookingId,
    bool isHourly = false,
    String? driverId,
    String? token,
  }) async {
    final path = isHourly
        ? 'drivers/complete-trip/HourlyBooking'
        : 'drivers/complete-trip';

    final data = {
      'bookingID': bookingId,
      'bookingId': bookingId,
      'driverID': ?driverId,
      'driverId': ?driverId,
    };

    try {
      final response = await _dio.post(
        path,
        data: data,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        
        // Retry for 401 Unauthorized
        if (statusCode == 401) {
          debugPrint('🔄 completeBooking │ 401 detected, attempting token refresh retry...');
          final newToken = await ensureValidToken();
          if (newToken != null) {
            try {
              final retryResponse = await _dio.post(
                path,
                data: data,
                options: _authOptions(newToken),
              );
              return _success(retryResponse);
            } catch (retryError) {
              return _handleError(retryError);
            }
          }
        }
        
        // Fallback for 404 Not Found on regular bookings
        if (statusCode == 404 && !isHourly) {
          debugPrint('🔄 completeBooking │ 404 detected on regular trip, falling back to status update...');
          return await updateBookingStatus(
            bookingId: bookingId,
            status: 'C', // Completed
            isHourly: false,
            token: token,
          );
        }
      }
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
      if (vehicleId == null) return {'success': false, 'message': 'Vehicle ID is required'};
      
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
  Future<Map<String, dynamic>> registerFcmToken({
    required String userId,
    required String fcmToken,
    String? token,
  }) async {
    try {
      final response = await _dio.post(
        '/users/$userId/fcm-token',
        data: {'fcmToken': fcmToken},
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Reviews
  // ---------------------------------------------------------------------------

  /// Submit a review for a booking.
  ///
  /// Format:
  /// {
  /// Fetch all reviews.
  ///
  /// Calls `GET /api/reviews`.
  Future<List<ReviewModel>> getAllReviews({String? token}) async {
    try {
      final response = await _dio.get(
        '/reviews',
        options: token != null ? _authOptions(token) : null,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          final reviewList = data['data'] as List?;
          if (reviewList != null) {
            return reviewList
                .map((r) => ReviewModel.fromJson(r as Map<String, dynamic>))
                .toList();
          }
        }
      }
      return [];
    } catch (e) {
      debugPrint('getAllReviews error: $e');
      return [];
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

      debugPrint('🌐 API │ Error [$statusCode]: $message');
      return {
        'success': false,
        'statusCode': statusCode,
        'message': message,
        if (data is Map<String, dynamic>) ...data,
      };
    }

    debugPrint('🌐 API │ Unexpected error: $error');
    return {
      'success': false,
      'message': 'Something went wrong. Please try again.',
    };
  }
}
