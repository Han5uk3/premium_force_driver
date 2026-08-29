import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:premium_force_driver/api/apis.dart';
import 'package:premium_force_driver/api/driver_api_v2.dart';
import 'package:premium_force_driver/storage/user_local_storage.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Top-level background handler (must be a top-level / static function)
// ──────────────────────────────────────────────────────────────────────────────

/// Called by FCM when a data-only message arrives while the app is terminated
/// or in the background.  Keep this as lightweight as possible – no UI work.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the time this is called, but
  // FlutterLocalNotifications may not be; initialise it here if you need to
  // show a notification from a data-only message in the background.
}

// ──────────────────────────────────────────────────────────────────────────────
// Android notification channel
// ──────────────────────────────────────────────────────────────────────────────

const AndroidNotificationChannel
_highImportanceChannel = AndroidNotificationChannel(
  'premium_force_high_importance', // must match the channel id in the manifest
  'Premium Force Alerts',
  description: 'Booking updates and important alerts from Premium Force.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

// ──────────────────────────────────────────────────────────────────────────────
// NotificationService
// ──────────────────────────────────────────────────────────────────────────────

/// Manages FCM token lifecycle and displays local notifications for foreground
/// messages on both Android and iOS.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;

  /// The current FCM registration token (may be null before [init] is called).
  String? get fcmToken => _fcmToken;

  // ── Callback invoked when a notification is tapped (foreground or from tray)
  void Function(RemoteMessage)? onNotificationTap;

  // ── Callback invoked when a new FCM token is issued / refreshed
  void Function(String token)? onTokenRefresh;

  /// Invoked when a push arrives, whether it was tapped or simply delivered
  /// while the app was open.
  ///
  /// The notification centre and the trip list are both server-backed, so the
  /// app answers a push by re-reading them rather than by keeping its own copy
  /// of the message.
  void Function(RemoteMessage message)? onMessageReceived;

  // ---------------------------------------------------------------------------
  // Initialise
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    // 1. Request permission (iOS / Android 13+)
    await _requestPermission();

    // 2. Set up local notifications plugin & channel
    await _initLocalNotifications();

    // 3. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 4. Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Message-opened-from-notification-tray handler
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      onMessageReceived?.call(msg);
      onNotificationTap?.call(msg);
    });

    // 6. Handle messages that launched the app from terminated state
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      onMessageReceived?.call(initialMessage);
      onNotificationTap?.call(initialMessage);
    }

    // 7. Fetch + cache the FCM token
    await _fetchToken();

    // 8. Listen for token refreshes → update Hive automatically
    _fcm.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      await UserLocalStorage.saveFcmToken(newToken);
      await _updateTokenOnBackend(newToken);
      onTokenRefresh?.call(newToken);
    });
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  Future<void> _requestPermission() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // iOS: needed to receive foreground notifications as banners
    if (Platform.isIOS) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Local notifications setup
  // ---------------------------------------------------------------------------

  Future<void> _initLocalNotifications() async {
    // Android init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS / macOS init
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false, // already requested via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _localPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Payload is the serialised RemoteMessage JSON we stored when showing
        // the notification; decode and forward to the tap callback.
        if (details.payload != null) {
          try {
            final map = jsonDecode(details.payload!) as Map<String, dynamic>;
            final msg = RemoteMessage.fromMap(map);
            onNotificationTap?.call(msg);
          } catch (_) {}
        }
      },
    );

    // Create the Android high-importance channel once
    if (Platform.isAndroid) {
      await _localPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_highImportanceChannel);
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground message handler
  // ---------------------------------------------------------------------------

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // The server already holds this notification; tell the app to re-read its
    // feed so the list and the unread badge pick it up.
    onMessageReceived?.call(message);

    final notification = message.notification;
    if (notification == null) return;

    // On iOS, `setForegroundNotificationPresentationOptions(alert: true)`
    // already tells the system to display the banner for every foreground FCM
    // message.  Calling `_localPlugin.show()` on top of that creates a second,
    // duplicate notification.  Android has no equivalent auto-display API, so
    // the manual local notification is still needed there.
    if (Platform.isAndroid) {
      await _localPlugin.show(
        // Use hashCode so successive notifications don't overwrite each other
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _highImportanceChannel.id,
            _highImportanceChannel.name,
            channelDescription: _highImportanceChannel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        // Serialise the full message so we can reconstruct it on tap
        payload: jsonEncode(message.toMap()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Token helpers
  // ---------------------------------------------------------------------------

  Future<void> _fetchToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      // Persist immediately so the rest of the app can read it via Hive
      if (_fcmToken != null) {
        await UserLocalStorage.saveFcmToken(_fcmToken!);
        await _updateTokenOnBackend(_fcmToken!);
      }
    } on FirebaseException catch (e) {
      if (e.code == 'apns-token-not-set') {
        // iOS Simulator does not support APNS, so FCM cannot issue a token.
        // Push notifications will only work on a physical iOS device.
      }
    } catch (e) {
      // No token this run; push stays off until the next fetch attempt.
    }
  }

  /// Call this to force-fetch the current token (e.g., after login).
  Future<String?> getToken() async {
    if (_fcmToken == null) await _fetchToken();
    return _fcmToken;
  }

  /// Explicitly sync the current token with the backend.
  /// Call this after login or signup to ensure the backend has the latest token.
  Future<void> syncTokenWithBackend() async {
    final token = await getToken();
    if (token != null) {
      await _updateTokenOnBackend(token);
    }
  }

  /// Deletes the FCM token (call on logout so this device stops receiving
  /// notifications for the previous user).
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      _fcmToken = null;
      await UserLocalStorage.clearFcmToken();
    } catch (e) {
      // Best-effort on logout: a token that cannot be deleted now is replaced
      // at the next login.
    }
  }

  /// Synchronise the local FCM token with the backend if the user is logged in.
  Future<void> _updateTokenOnBackend(String fcmToken) async {
    final uid = UserLocalStorage.getUserId();
    final authToken = UserLocalStorage.getToken();

    if (uid != null && uid.isNotEmpty) {
      try {
        await ApiService().updateFcmToken(
          userid: uid,
          fcmToken: fcmToken,
          token: authToken,
        );

        // The token only. Every path that reaches here has just sent the
        // driver's locale already — verify-otp and registration both carry it,
        // and a session restore has not changed it — so re-sending it would
        // only be a second call saying the same thing. Switching language syncs
        // itself.
        await DriverApiV2().updateSettings(fcmToken: fcmToken);
      } catch (e) {
        // Best-effort sync: the token is re-sent at the next login or refresh.
      }
    }
  }
}
