import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/models/user.dart';
import 'package:premium_force_driver/models/driver.dart';
import 'package:premium_force_driver/models/booking.dart';
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

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
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
    // If token is not expiring soon, use it as-is
    if (!UserLocalStorage.isTokenExpiredOrExpiring()) {
      return UserLocalStorage.getToken();
    }

    // Token is expiring or expired, try to refresh
    final refreshToken = UserLocalStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint('❌ Cannot refresh token: no refresh token stored');
      return null;
    }

    try {
      debugPrint('🔄 Auto-refreshing access token...');
      final result = await refreshAccessToken(refreshToken: refreshToken);

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
          debugPrint('✅ Access token refreshed successfully');
          return newAccessToken;
        }
      }

      debugPrint('❌ Failed to refresh token: ${result['message']}');
      return null;
    } catch (e) {
      debugPrint('❌ Token refresh error: $e');
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
        'location': ?location,
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
        'email': email,
        'countryCode': countryCode,
        'phoneNumber': phoneNumber,
        'location': ?location,
        if (lat != null) 'lat': lat.toString(),
        if (long != null) 'long': long.toString(),
        'licenseNumber': ?licenseNumber,
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
        List<BookingModel> bookings = [];

        if (data is Map<String, dynamic> && data.containsKey('bookings')) {
          final bookingsList = data['bookings'] as List?;
          if (bookingsList != null) {
            bookings = bookingsList
                .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
                .toList();
          }
        } else if (data is List) {
          bookings = data
              .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
              .toList();
        }

        return bookings;
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
        List<BookingModel> bookings = [];

        if (data is Map<String, dynamic> &&
            (data.containsKey('bookings') || data.containsKey('data'))) {
          final bookingsList = (data['bookings'] ?? data['data']) as List?;
          if (bookingsList != null) {
            bookings =
                bookingsList
                    .map(
                      (b) => BookingModel.fromJson(b as Map<String, dynamic>),
                    )
                    .toList();
          }
        } else if (data is List) {
          bookings =
              data
                  .map((b) => BookingModel.fromJson(b as Map<String, dynamic>))
                  .toList();
        }

        return bookings;
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
  /// Calls `PUT /api/bookings/{bookingId}` or `/api/hourly-bookings/{bookingId}` to update status to "AC" (Accepted).
  Future<Map<String, dynamic>> acceptBooking({
    required String bookingId,
    bool isHourly = false,
    String? token,
  }) async {
    try {
      final path = isHourly ? '/hourly-bookings/$bookingId' : '/bookings/$bookingId';
      final response = await _dio.put(
        path,
        data: {
          'status': 'AC',
          'bookingStatus': 'AC',
        }, // AC = Accepted
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Update booking status.
  ///
  /// Calls `PUT /api/bookings/{bookingId}` or `/api/hourly-bookings/{bookingId}`.
  Future<Map<String, dynamic>> updateBookingStatus({
    required String bookingId,
    required String status,
    bool isHourly = false,
    String? token,
  }) async {
    try {
      final path = isHourly ? '/hourly-bookings/$bookingId' : '/bookings/$bookingId';
      final response = await _dio.put(
        path,
        data: {
          'bookingStatus': status,
          'status': status,
        }, // Send both to be safe
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Reject a booking by [bookingId].
  ///
  /// Calls `PUT /api/bookings/{bookingId}` or `/api/hourly-bookings/{bookingId}` to update status to "CA" (Cancelled).
  Future<Map<String, dynamic>> rejectBooking({
    required String bookingId,
    bool isHourly = false,
    String? token,
  }) async {
    try {
      final path = isHourly ? '/hourly-bookings/$bookingId' : '/bookings/$bookingId';
      final response = await _dio.put(
        path,
        data: {
          'status': 'CA',
          'bookingStatus': 'CA',
        }, // CA = Cancelled
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
  Future<Map<String, dynamic>> saveChauffeurTripTimes({
    required String bookingId,
    required String startTime,
    required String stopTime,
    required int tripDurationSeconds,
    int extraHours = 0,
    String? token,
  }) async {
    try {
      final authToken = token ?? UserLocalStorage.getToken();
      final data = <String, dynamic>{
        'trackingStartTime': startTime,
        'trackingStopTime': stopTime,
        'tripDurationSeconds': tripDurationSeconds,
      };
      if (extraHours > 0) {
        data['extraHours'] = extraHours;
      }
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

  /// Mark a booking as completed (trip finished).
  ///
  /// Calls `POST /api/drivers/complete-booking/` endpoint.
  Future<Map<String, dynamic>> completeBooking({
    required String bookingId,
    required String driverId,
    String? token,
  }) async {
    try {
      final response = await _dio.post(
        '/drivers/complete-booking/',
        data: {'bookingId': bookingId, 'driverId': driverId},
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
