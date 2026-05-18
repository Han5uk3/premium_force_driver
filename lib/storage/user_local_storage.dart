import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Local storage service using Hive for persisting minimal user credentials.
///
/// Only stores **userId**, **phoneNumber**, and auth tokens locally.
/// Full user data is fetched from the backend via `GET /api/users/:id`
/// whenever needed.
///
/// Usage:
/// ```dart
/// // Initialize once (in main.dart)
/// await UserLocalStorage.init();
///
/// // Save credentials after login
/// await UserLocalStorage.saveUserCredentials(userId: '...', phoneNumber: '...');
///
/// // Read stored id / phone
/// final uid = UserLocalStorage.getUserId();
///
/// // Check if logged in
/// if (UserLocalStorage.isLoggedIn) { ... }
///
/// // Clear on logout
/// await UserLocalStorage.clearUser();
/// ```
class UserLocalStorage {
  static const String _boxName = 'user_box';

  // Keys
  static const String _userIdKey = 'user_id';
  static const String _phoneNumberKey = 'phone_number';
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry'; // Unix timestamp in ms
  static const String _fcmTokenKey = 'fcm_token';
  static const String _notificationStatusKey = 'notification_status';
  static const String _driverProfileKey = 'driver_profile';
  static const String _languageKey = 'app_language';

  static late Box<dynamic> _box;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Call once before runApp.
  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    debugPrint('💾 UserLocalStorage initialized');
  }

  // ---------------------------------------------------------------------------
  // User Credentials (minimal — only id + phone)
  // ---------------------------------------------------------------------------

  /// Save only the userId and phoneNumber after a successful login/signup.
  static Future<void> saveUserCredentials({
    required String userId,
    required String phoneNumber,
  }) async {
    await _box.put(_userIdKey, userId);
    await _box.put(_phoneNumberKey, phoneNumber);
    debugPrint('💾 User credentials saved: id=$userId, phone=$phoneNumber');
  }

  /// Retrieve the stored userId, or `null` if not logged in.
  static String? getUserId() {
    return _box.get(_userIdKey) as String?;
  }

  /// Retrieve the stored phone number, or `null`.
  static String? getPhoneNumber() {
    return _box.get(_phoneNumberKey) as String?;
  }

  /// Remove all stored user data (logout).
  static Future<void> clearUser() async {
    await _box.delete(_userIdKey);
    await _box.delete(_phoneNumberKey);
    await _box.delete(_tokenKey);
    await _box.delete(_refreshTokenKey);
    await _box.delete(_tokenExpiryKey);
    await _box.delete(_driverProfileKey);
    debugPrint('💾 User data cleared');
  }

  // ---------------------------------------------------------------------------
  // Auth Tokens (access + refresh)
  // ---------------------------------------------------------------------------

  /// Persist the access token (JWT).
  static Future<void> saveToken(String token) async {
    await _box.put(_tokenKey, token);
  }

  /// Retrieve the stored access token, or `null`.
  static String? getToken() {
    return _box.get(_tokenKey) as String?;
  }

  /// Persist the refresh token.
  static Future<void> saveRefreshToken(String token) async {
    await _box.put(_refreshTokenKey, token);
  }

  /// Retrieve the stored refresh token, or `null`.
  static String? getRefreshToken() {
    return _box.get(_refreshTokenKey) as String?;
  }

  /// Save both tokens at once (convenience method after login/verify).
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    int? expiryDurationSeconds, // usually 3600 = 1 hour
  }) async {
    await _box.put(_tokenKey, accessToken);
    await _box.put(_refreshTokenKey, refreshToken);

    // Default to 1 hour if no duration provided
    final seconds = expiryDurationSeconds ?? 3600;
    final expiryMs = DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch;
    await _box.put(_tokenExpiryKey, expiryMs);

    debugPrint('💾 Tokens saved (expires in ${seconds}s)');
  }

  /// Check if access token is expired or about to expire (within 5 minutes).
  static bool isTokenExpiredOrExpiring() {
    final expiryMs = _box.get(_tokenExpiryKey) as int?;
    if (expiryMs == null) return true; // No expiry info = assume expired

    final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    final now = DateTime.now();
    final bufferDuration = const Duration(minutes: 5);

    // Return true if expired or within 5 minutes of expiry
    return now.isAfter(expiryTime.subtract(bufferDuration));
  }

  /// Get time remaining on token (in seconds), or 0 if expired.
  static int getTokenTimeRemaining() {
    final expiryMs = _box.get(_tokenExpiryKey) as int?;
    if (expiryMs == null) return 0;

    final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    final remaining = expiryTime.difference(DateTime.now()).inSeconds;

    return remaining > 0 ? remaining : 0;
  }

  // ---------------------------------------------------------------------------
  // Convenience
  // ---------------------------------------------------------------------------

  /// Whether a user is currently logged in (userId is stored).
  static bool get isLoggedIn => _box.containsKey(_userIdKey);

  /// Persist the full driver profile data.
  static Future<void> saveDriver(Map<String, dynamic> driverJson) async {
    await _box.put(_driverProfileKey, driverJson);
  }

  /// Retrieve the cached driver profile data.
  static Map<String, dynamic>? getDriver() {
    final data = _box.get(_driverProfileKey);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Alias for [getUserId] — for backward compatibility.
  static String? get userId => getUserId();

  // ---------------------------------------------------------------------------
  // FCM Token
  // ---------------------------------------------------------------------------

  /// Persist the FCM registration token.
  static Future<void> saveFcmToken(String token) async {
    await _box.put(_fcmTokenKey, token);
    debugPrint('💾 FCM token saved');
  }

  /// Retrieve the stored FCM token, or `null` if never saved.
  static String? getFcmToken() {
    return _box.get(_fcmTokenKey) as String?;
  }

  /// Clear the stored FCM token (e.g. on logout / token rotation).
  static Future<void> clearFcmToken() async {
    await _box.delete(_fcmTokenKey);
  }
  // ---------------------------------------------------------------------------
  // User Preferences
  // ---------------------------------------------------------------------------

  /// Persist the notification active status.
  static Future<void> saveNotificationStatus(bool status) async {
    await _box.put(_notificationStatusKey, status);
  }

  /// Retrieve the notification status, defaults to true.
  static bool getNotificationStatus() {
    return _box.get(_notificationStatusKey, defaultValue: true) as bool;
  }

  // ---------------------------------------------------------------------------
  // Language Preference
  // ---------------------------------------------------------------------------

  /// Persist the selected language code.
  static Future<void> saveLanguage(String languageCode) async {
    await _box.put(_languageKey, languageCode);
  }

  /// Retrieve the stored language code, defaults to 'en'.
  static String getLanguage() {
    return _box.get(_languageKey, defaultValue: 'en') as String;
  }

  // ---------------------------------------------------------------------------
  // Notifications Storage
  // ---------------------------------------------------------------------------

  static const String _notificationsListKey = 'notifications_list';

  /// Save all notifications to local storage.
  static Future<void> saveNotifications(List<dynamic> notifications) async {
    await _box.put(_notificationsListKey, notifications);
  }

  /// Retrieve the list of all stored notifications.
  static List<Map<String, dynamic>> getNotifications() {
    final raw = _box.get(_notificationsListKey);
    if (raw == null) return [];

    try {
      final list = List<dynamic>.from(raw as List);
      return list.map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).where((item) => item.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Save a single notification item.
  static Future<void> saveNotification(Map<String, dynamic> notification) async {
    final list = getNotifications();

    final id = notification['id'];
    if (id != null && list.any((e) => e['id'] == id)) {
      return;
    }

    list.insert(0, notification);
    await saveNotifications(list);
  }

  /// Mark a single notification as read.
  static Future<void> markNotificationAsRead(String id) async {
    final list = getNotifications();
    var changed = false;
    for (var item in list) {
      if (item['id'] == id) {
        item['read'] = true;
        changed = true;
        break;
      }
    }
    if (changed) {
      await saveNotifications(list);
    }
  }

  /// Mark all notifications as read.
  static Future<void> markAllNotificationsAsRead() async {
    final list = getNotifications();
    var changed = false;
    for (var item in list) {
      if (!(item['read'] as bool? ?? false)) {
        item['read'] = true;
        changed = true;
      }
    }
    if (changed) {
      await saveNotifications(list);
    }
  }

  /// Delete a single notification.
  static Future<void> deleteNotification(String id) async {
    final list = getNotifications();
    final initialLength = list.length;
    list.removeWhere((item) => item['id'] == id);
    if (list.length != initialLength) {
      await saveNotifications(list);
    }
  }

  /// Clear all stored notifications.
  static Future<void> clearNotifications() async {
    await _box.delete(_notificationsListKey);
  }
}
