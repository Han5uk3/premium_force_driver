import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/api_result.dart';
import 'package:premium_force_driver/api/apis.dart';
import 'package:premium_force_driver/models/v2/notification_v2.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/storage/user_local_storage.dart';
import 'package:premium_force_driver/utils/json_utils.dart';

/// Client for the v2 driver API (`/api/v2/`).
///
/// Covers the three surfaces the driver app needs from v2: the trip list and
/// detail (`driver/bookings/...`), the linear status progression that moves a
/// trip from assignment to completion, and the driver's own notification
/// centre. Settings live here too, though that one endpoint is served from the
/// unversioned `/api/` root.
///
/// Auth reuses the tokens [ApiService] already manages — including its
/// single-flight refresh — so both clients stay in step and only one refresh is
/// ever in flight.
///
/// Usage:
/// ```dart
/// final api = DriverApiV2();
/// final trips = await api.getMyTrips(filter: TripFilterV2.active);
/// if (!trips.success) showError(trips.message);
/// ```
class DriverApiV2 {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// The unversioned API root.
  static const String _apiRoot = 'https://api.premiumforcegroup.com/api/';

  static const String _baseUrl = '${_apiRoot}v2/';

  /// Driver settings are served from the unversioned root, not from v2.
  ///
  /// Absolute, so [Dio] uses it in place of [_baseUrl] while the request still
  /// goes through this client's auth and token-refresh interceptors.
  static const String _settingsUrl = '${_apiRoot}drivers/settings';

  // ---------------------------------------------------------------------------
  // Singleton + Dio instance
  // ---------------------------------------------------------------------------

  static final DriverApiV2 _instance = DriverApiV2._internal();
  factory DriverApiV2() => _instance;

  late final Dio _dio;

  DriverApiV2._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
        // The status endpoint answers an out-of-order transition with a 400 whose
        // message names the current state — a displayable outcome, not a crash.
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          final token = UserLocalStorage.getToken();
          if (token != null &&
              token.isNotEmpty &&
              options.headers['Authorization'] == null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode != 401) return handler.next(e);

          // Delegates to the v1 client's refresh so the two never race, and so a
          // dead refresh token still triggers its onSessionExpired callback.
          final newToken = await ApiService().ensureValidToken(
            forceRefresh: true,
          );
          if (newToken == null) return handler.next(e);

          try {
            e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final retried = await _dio.fetch(e.requestOptions);
            return handler.resolve(retried);
          } catch (_) {
            return handler.next(e);
          }
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint('🚘 v2 │ $obj'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Trips
  // ---------------------------------------------------------------------------

  /// The driver's trips, paginated and filtered server-side.
  ///
  /// [filter] narrows to `active` (assigned through to in-progress) or
  /// `completed`; omitting it returns every trip assigned to the driver.
  Future<ApiResult<TripListPage>> getMyTrips({
    TripFilterV2? filter,
    int page = 1,
    int limit = 10,
  }) {
    return _request(
      () => _dio.get(
        'driver/bookings/my-trips',
        queryParameters: {
          if (filter != null) 'filter': filter.wireValue,
          'page': page,
          'limit': limit,
        },
      ),
      parse: (payload) => TripListPage.fromJson(asMap(payload)),
    );
  }

  /// Full trip detail, including the progress timeline.
  Future<ApiResult<TripV2>> getTripById(String tripId) {
    return _request(
      () => _dio.get('driver/bookings/$tripId'),
      parse: (payload) => TripV2.fromJson(asMap(payload)),
    );
  }

  /// Advance a trip to [status], and record any extras when completing it.
  ///
  /// The backend only accepts the next status in the chain
  /// (`driver_assigned` → `driver_en_route` → `driver_arrived` →
  /// `trip_started` → `completed`) and rejects a skip with a 400 whose message
  /// names the current state; [TripStatusV2.next] is what the UI should offer so
  /// that never happens by accident.
  ///
  /// The extras are only meaningful on completion — the endpoint stores them on
  /// the booking and adds [extraAmount] to its grand total — so they are dropped
  /// for every other transition rather than being sent and ignored.
  Future<ApiResult<TripV2>> updateTripStatus({
    required String tripId,
    required TripStatusV2 status,
    double? extraAmount,
    ExtraPaymentMethodV2? extraPaymentMethod,
    String? extraNotes,
  }) {
    final isCompleting = status == TripStatusV2.completed;
    final amount = extraAmount ?? 0;
    final hasExtras = isCompleting && amount > 0;
    final notes = extraNotes?.trim();

    return _request(
      () => _dio.patch(
        'driver/bookings/$tripId/status',
        data: {
          'status': status.wireValue,
          if (hasExtras) 'extraAmount': amount,
          if (hasExtras)
            'extraPaymentMethod':
                (extraPaymentMethod ?? ExtraPaymentMethodV2.pos).wireValue,
          if (hasExtras && notes != null && notes.isNotEmpty)
            'extraNotes': notes,
        },
      ),
      parse: (payload) => TripV2.fromJson(asMap(payload)),
    );
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// One page of the driver's notifications, newest first, plus their
  /// account-wide unread count.
  Future<ApiResult<NotificationFeedPage>> getNotifications({
    int page = 1,
    int limit = 10,
  }) {
    return _request(
      () => _dio.get(
        'notifications/driver',
        queryParameters: {'page': page, 'limit': limit},
      ),
      parse: (payload) => NotificationFeedPage.fromJson(asMap(payload)),
    );
  }

  /// Mark one notification as read.
  Future<ApiResult<bool>> markNotificationAsRead(String notificationId) {
    return _request(
      () => _dio.patch('notifications/driver/$notificationId/read'),
      parse: (_) => true,
    );
  }

  /// Mark every notification as read, clearing the badge in one call.
  Future<ApiResult<bool>> markAllNotificationsAsRead() {
    return _request(
      () => _dio.patch('notifications/driver/read-all'),
      parse: (_) => true,
    );
  }

  /// Delete one notification.
  Future<ApiResult<bool>> deleteNotification(String notificationId) {
    return _request(
      () => _dio.delete('notifications/driver/$notificationId'),
      parse: (_) => true,
    );
  }

  /// Delete the whole feed.
  Future<ApiResult<bool>> clearNotifications() {
    return _request(
      () => _dio.delete('notifications/driver/clear-all'),
      parse: (_) => true,
    );
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  /// Update the driver's preferred language and/or device push token.
  ///
  /// The backend renders pushes and emails server-side, so it needs to know which
  /// language the driver reads. Both fields are optional; calling with neither is
  /// a no-op that reports success without touching the network.
  Future<ApiResult<DriverSettingsV2>> updateSettings({
    String? locale,
    String? fcmToken,
  }) {
    final body = <String, dynamic>{
      if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
      if (fcmToken != null && fcmToken.trim().isNotEmpty)
        'fcmToken': fcmToken.trim(),
    };

    if (body.isEmpty) {
      return Future.value(
        const ApiResult<DriverSettingsV2>.ok(DriverSettingsV2()),
      );
    }

    return _request(
      () => _dio.patch(_settingsUrl, data: body),
      parse: (payload) => DriverSettingsV2.fromJson(asMap(payload)),
    );
  }

  // ---------------------------------------------------------------------------
  // Internal plumbing
  // ---------------------------------------------------------------------------

  /// Run [send], unwrap the `{success, message, data}` envelope, and hand the
  /// inner payload to [parse].
  Future<ApiResult<T>> _request<T>(
    Future<Response<dynamic>> Function() send, {
    required T Function(dynamic payload) parse,
  }) async {
    try {
      final response = await send();
      final body = asMap(response.data);
      final status = response.statusCode ?? 0;
      final message = pickString(body, const ['message', 'error']);
      // `success` may be absent on bare payloads; fall back to the status code.
      final succeeded =
          pickBool(body, const ['success']) ?? (status >= 200 && status < 300);

      if (!succeeded || status >= 400) {
        // A 2xx carrying `success: false` is easy to miss in the raw log, so the
        // interpreted outcome is recorded separately.
        debugPrint(
          '🚫 v2 │ rejected [$status] → ${message ?? _statusMessage(status)}',
        );
        return ApiResult<T>.failure(
          message ?? _statusMessage(status),
          statusCode: status,
        );
      }

      // Endpoints nest their payload under `data`; a few return it at the root.
      final payload = body.containsKey('data') ? body['data'] : body;
      final parsed = parse(payload);
      debugPrint('✅ v2 │ parsed $T${message == null ? '' : ' → $message'}');
      return ApiResult<T>.ok(parsed, message: message);
    } on DioException catch (error) {
      return ApiResult<T>.failure(
        _dioMessage(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error, stackTrace) {
      // Almost always a shape mismatch between the response and the model. Named
      // explicitly because a parse failure must not take the trip screen down
      // while a driver is mid-ride.
      debugPrint('💥 v2 │ failed to parse $T: $error');
      debugPrint('$stackTrace');
      return ApiResult<T>.failure('Something went wrong. Please try again.');
    }
  }

  static String _statusMessage(int statusCode) => switch (statusCode) {
    400 => 'This action is not allowed right now.',
    401 => 'Your session has expired. Please sign in again.',
    403 => 'You are not allowed to perform this action.',
    404 => 'This trip could not be found.',
    409 => 'This trip has already been updated.',
    422 => 'Please check the details and try again.',
    _ => 'Server error ($statusCode). Please try again.',
  };

  static String _dioMessage(DioException error) {
    final data = error.response?.data;
    final serverMessage = data is Map
        ? pickString(asMap(data), const ['message', 'error'])
        : null;
    if (serverMessage != null) return serverMessage;

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'Request timed out. Please try again.',
      DioExceptionType.connectionError =>
        'No internet connection. Please check your network.',
      DioExceptionType.cancel => 'Request was cancelled.',
      _ => _statusMessage(error.response?.statusCode ?? 0),
    };
  }
}

/// The driver settings the backend now holds, echoed back by
/// `PATCH /api/drivers/settings`.
class DriverSettingsV2 {
  const DriverSettingsV2({this.driverId, this.locale, this.fcmToken});

  final String? driverId;

  /// `"en"` or `"ar"` — the language every push and email is rendered in.
  final String? locale;

  final String? fcmToken;

  factory DriverSettingsV2.fromJson(Map<String, dynamic> json) {
    return DriverSettingsV2(
      driverId: pickId(json, const ['driverId', 'driverID', '_id', 'id']),
      locale: pickString(json, const ['locale', 'language']),
      fcmToken: pickString(json, const ['fcmToken']),
    );
  }
}
