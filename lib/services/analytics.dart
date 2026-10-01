import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:premium_force_driver/models/v2/trip_v2.dart';

/// Product analytics, sent to Google Analytics through Firebase.
///
/// Every event the app reports is named here, so this file doubles as the list
/// of what is tracked. Call sites never touch [FirebaseAnalytics] directly.
///
/// Collection is off in debug builds, as Crashlytics is, so a developer's test
/// trips never land in the real numbers. To watch events arrive in the
/// console's DebugView, run with `--dart-define=ANALYTICS_DEBUG=true`.
///
/// Nothing personal is sent: the user id is the backend id — never the phone
/// number, email or name — and no event carries an address or free text.
///
/// Every call is best-effort and swallows its own errors, so it is safe to fire
/// without awaiting and can never break the flow it is reporting on.
///
/// Usage:
/// ```dart
/// await Firebase.initializeApp(...);
/// await Analytics.init();
/// ```
class Analytics {
  Analytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  /// Lets a debug build report, for checking events in DebugView.
  static const bool _collectInDebug = bool.fromEnvironment('ANALYTICS_DEBUG');

  /// Reports a `screen_view` as pages are pushed and popped. Belongs in
  /// `MaterialApp.navigatorObservers`.
  static final ScreenObserver screens = ScreenObserver._();

  /// Switch collection on or off for this build. Call once, straight after
  /// `Firebase.initializeApp`.
  ///
  /// The setting persists on the device, so it is written on every launch — a
  /// release build installed over a debug one would otherwise inherit "off".
  static Future<void> init() => _guard(
    () => _analytics.setAnalyticsCollectionEnabled(
      !kDebugMode || _collectInDebug,
    ),
  );

  // ---------------------------------------------------------------------------
  // Who is using the app
  // ---------------------------------------------------------------------------

  /// Attribute every later event to the signed-in driver. Pass null on logout.
  static Future<void> setUser(String? userId) => _guard(
    () => _analytics.setUserId(
      id: (userId == null || userId.isEmpty) ? null : userId,
    ),
  );

  /// The language the app is shown in, which can differ from the device's.
  static Future<void> setLanguage(String languageCode) => _guard(
    () => _analytics.setUserProperty(name: 'app_language', value: languageCode),
  );

  // ---------------------------------------------------------------------------
  // Screens
  // ---------------------------------------------------------------------------

  /// Report a screen that is not a route of its own, such as one of Home's
  /// tabs. Routes are reported by [screens].
  static Future<void> logScreen(String name) =>
      _guard(() => _analytics.logScreenView(screenName: name));

  // ---------------------------------------------------------------------------
  // Account
  // ---------------------------------------------------------------------------

  /// A registered driver signed in. Drivers only sign in by phone.
  static Future<void> logLogin() =>
      _guard(() => _analytics.logLogin(loginMethod: 'phone'));

  /// A new driver finished registering.
  static Future<void> logSignUp() =>
      _guard(() => _analytics.logSignUp(signUpMethod: 'phone'));

  // ---------------------------------------------------------------------------
  // Work
  // ---------------------------------------------------------------------------

  /// The driver went on or off shift.
  static Future<void> logShift({required bool started}) => _guard(
    () => _analytics.logEvent(name: started ? 'shift_started' : 'shift_ended'),
  );

  /// The driver moved a trip on to [status].
  ///
  /// One event per step rather than one with a status parameter, so each step
  /// is countable in the standard reports and usable as a funnel step without
  /// registering a custom dimension first.
  static Future<void> logTripAdvanced(
    TripStatusV2 status, {
    String? serviceType,
  }) {
    final name = switch (status) {
      TripStatusV2.driverEnRoute => 'trip_en_route',
      TripStatusV2.driverArrived => 'trip_arrived',
      TripStatusV2.tripStarted => 'trip_started',
      TripStatusV2.completed => 'trip_completed',
      _ => null,
    };
    if (name == null) return Future.value();

    return _guard(
      () => _analytics.logEvent(
        name: name,
        parameters: {'service_type': ?serviceType},
      ),
    );
  }

  // ---------------------------------------------------------------------------

  static Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // Reporting is best-effort; it must never break what it reports on.
    }
  }
}

/// Reports a `screen_view` for each page the navigator shows.
///
/// A page is reported under its route's name, so a route pushed without one is
/// skipped — Home relies on that, since a [ScreenReporter] reports whichever
/// tab is showing instead. Dialogs and sheets are not pages: they are never
/// reported, and closing one does not report the page beneath it again.
///
/// Typed on [PageRoute] rather than [ModalRoute] for that same reason: a
/// [RouteAware] subscriber is told `didPopNext` only when a page above it is
/// popped, not whenever a dialog over it closes.
class ScreenObserver extends RouteObserver<PageRoute<dynamic>> {
  ScreenObserver._();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _report(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _report(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute && previousRoute != null) _report(previousRoute);
  }

  void _report(Route<dynamic> route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null) return;

    // `MaterialApp.home` is registered under '/', and here that is the splash.
    Analytics.logScreen(
      name == Navigator.defaultRouteName ? Screens.splash : name,
    );
  }
}

/// Reports [screen] whenever it comes into view: when its page is pushed, when
/// [screen] changes, and when a page pushed above it is popped.
///
/// For screens that are not routes of their own, such as Home's tabs. The page
/// it sits in must be pushed without a name, or that is reported as well.
///
/// Wrap something small. A route change rebuilds this widget, but it hands back
/// the same [child], so nothing beneath it rebuilds along with it — whereas the
/// same lookup in Home itself would rebuild every tab each time a page opened
/// or closed over it.
class ScreenReporter extends StatefulWidget {
  const ScreenReporter({super.key, required this.screen, required this.child});

  final String screen;
  final Widget child;

  @override
  State<ScreenReporter> createState() => _ScreenReporterState();
}

class _ScreenReporterState extends State<ScreenReporter> with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) Analytics.screens.subscribe(this, route);
  }

  @override
  void didUpdateWidget(ScreenReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.screen != oldWidget.screen) _report();
  }

  @override
  void dispose() {
    Analytics.screens.unsubscribe(this);
    super.dispose();
  }

  // Also called once on subscribing, which is how the first screen is reported.
  @override
  void didPush() => _report();

  @override
  void didPopNext() => _report();

  void _report() => Analytics.logScreen(widget.screen);

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Screen names as they appear in Analytics.
///
/// A route carries its name in [RouteSettings]; Home's tabs are reported by a
/// [ScreenReporter].
abstract final class Screens {
  static const splash = 'splash';
  static const updateRequired = 'update_required';
  static const login = 'login';
  static const otp = 'otp';
  static const signUp = 'sign_up';
  static const blocked = 'blocked';
  static const locationPicker = 'location_picker';

  // Home's tabs.
  static const dashboard = 'dashboard';
  static const trips = 'trips';
  static const account = 'account';

  static const manageProfile = 'manage_profile';
  static const notifications = 'notifications';
  static const tripDetails = 'trip_details';
}
