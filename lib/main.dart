import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_driver/splashscreen/splashscreen.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_driver/providers/auth_provider.dart';
import 'package:premium_force_driver/providers/user_provider.dart';
import 'package:premium_force_driver/providers/notifications_provider.dart';
import 'package:premium_force_driver/providers/trips_provider.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:premium_force_driver/firebase_options.dart';
import 'package:premium_force_driver/api/driver_api_v2.dart';
import 'package:premium_force_driver/storage/user_local_storage.dart';
import 'package:premium_force_driver/services/notification_service.dart';
import 'package:premium_force_driver/services/crash_reporting.dart';
import 'package:premium_force_driver/home/notifications_page.dart';

/// Global navigator key – allows navigating from outside a widget tree
/// (e.g. when the user taps a push notification).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// The notification centre's state.
///
/// Created outside the widget tree so a push arriving before (or without) any
/// screen being mounted can still refresh the feed and the unread badge.
final NotificationsProvider notificationsProvider = NotificationsProvider();

/// The driver's trips.
///
/// Shared by the dashboard, the trips screen and the detail screen so a status
/// change on one is reflected on the others without a round trip.
final TripsProvider tripsProvider = TripsProvider();

/// The darkest ground the screens are painted on — the bottom of their
/// gradients. Used wherever Flutter would otherwise leave a gap for the white
/// default to show through. Kept in step with `app_background` in the Android
/// resources and the iOS launch screen.
const Color _appBackground = Color(0xFF1A1A1A);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
    } else {
      rethrow;
    }
  }
  await CrashReporting.init();

  await UserLocalStorage.init();

  // A driver who is already signed in never passes through
  // `saveUserCredentials` again, so tag their reports from the stored id.
  CrashReporting.setUser(UserLocalStorage.getUserId());

  // Initialise push notifications
  await NotificationService.instance.init();

  // Optional: react to notification taps globally
  NotificationService.instance.onNotificationTap = _handleNotificationTap;

  // A push only announces that something happened — a new assignment, a
  // cancellation — so the app answers by re-reading the feed and the trips.
  NotificationService.instance.onMessageReceived = (_) {
    notificationsProvider.refresh(silent: true);
    tripsProvider.refresh(silent: true);
  };

  runApp(const MainApp());
}

/// Invoked when the user taps a notification (foreground banner, tray, or
/// when the app is launched from a terminated-state notification).
void _handleNotificationTap(RemoteMessage message) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => const NotificationsPage()),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MainAppState? state = context.findAncestorStateOfType<_MainAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    final langCode = UserLocalStorage.getLanguage();
    _locale = Locale(langCode);
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    UserLocalStorage.saveLanguage(locale.languageCode);
    _syncLocaleWithBackend(locale.languageCode);
  }

  /// Mirror the chosen language onto the driver's account.
  ///
  /// Pushes and emails are rendered server-side, so the backend has to know
  /// which language to use. The call is fire-and-forget: the UI has already
  /// switched and Hive holds the choice, so a failure here only means the server
  /// keeps using the previous language until the next successful sync.
  void _syncLocaleWithBackend(String languageCode) {
    if (!UserLocalStorage.isLoggedIn) return;

    DriverApiV2()
        .updateSettings(
          locale: languageCode,
          fcmToken: UserLocalStorage.getFcmToken(),
        )
        .then((result) {});
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider.value(value: tripsProvider),
        ChangeNotifierProvider.value(value: notificationsProvider),
      ],
      // The ground behind the [SafeArea]'s bottom inset.
      //
      // That strip is outside [MaterialApp], so nothing in Flutter paints it and
      // the native window background shows through — white on a phone in light
      // mode, which put a white band under every screen.
      child: ColoredBox(
        color: _appBackground,
        child: SafeArea(
          top: false,
          bottom: Platform.isAndroid ? true : false,
          child: MaterialApp(
            title: "Premium Force Driver",
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            locale: _locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            // The app declared no theme at all, so every text field inherited
            // Material's defaults — which is why the selection handle came up
            // purple. Only the selection colours are set here; everything else
            // stays at the default this app was already running on.
            theme: ThemeData(
              // The platform default transitions, stated explicitly.
              //
              // Page changes fade the incoming screen in over a background that
              // defaults to the theme's surface — near-white, since this theme is
              // otherwise Material's light default. Every screen here is dark, so
              // that background reads as a white flash between login and Home
              // (and on every other push). There is no way to recolour it from
              // here: PredictiveBackPageTransitionsBuilder takes no arguments and
              // hardcodes `const FadeForwardsPageTransitionsBuilder()` as its
              // non-gesture fallback, so the only lever is ColorScheme.surface —
              // which would also repaint Scaffold, Card and Dialog while
              // onSurface stayed near-black. Left as-is until this theme moves to
              // a full dark ColorScheme.
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
              textSelectionTheme: const TextSelectionThemeData(
                // Every screen here is dark, and the country picker's search
                // field takes its cursor from the ambient theme — it has no
                // setting of its own. A field that wants a different cursor
                // still overrides this locally.
                cursorColor: Colors.white,
                // Silver, matching the app's own accent grey, in place of the
                // Material purple.
                selectionHandleColor: Color(0xFFC0C0C0),
                selectionColor: Color(0x55C0C0C0),
              ),
            ),
            home: const SplashScreen(),
          ),
        ),
      ),
    );
  }
}
