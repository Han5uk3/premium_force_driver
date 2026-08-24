import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/storage/user_local_storage.dart';

/// Publishes the driver's live position for the ride they are on.
///
/// **The backend decides when this runs.** [syncWithTrip] takes a trip as the
/// server last reported it and reconciles sharing against
/// [TripStatusV2.sharesLocation]: sharing starts the moment the driver sets off
/// for the pickup — `driver_en_route` — and stops once the ride is over, so
/// the customer can watch the car approach and not just carry them. It is called after every accepted status change and
/// after every refresh of the active list, so the app cannot end up publishing
/// a ride the backend considers finished — or stay silent through one it
/// considers live, which is also how sharing resumes after the app is killed
/// mid-ride.
///
/// **Where it writes.** Both nodes are keyed by the booking's Mongo `_id`, the
/// same id the customer app subscribes with:
///   - `bookings/{bookingId}/tracking_session` — written twice, at start and at
///     stop.
///   - `bookings/{bookingId}/driver_location` — `{lat, lng, timestamp}`,
///     overwritten in place as the car moves.
///
/// **Cost.** Realtime Database bills on what crosses the wire, so the position
/// stream is sampled every [sampleInterval] but only *published* when the car
/// has moved [_minWriteDistanceMeters], or when [_heartbeatInterval] has passed
/// without a write. A car standing still therefore costs one small write a
/// minute instead of thirty, while a moving one publishes at the full sample
/// rate. Nothing else is written: no per-tick metadata, no history.
/// Which leg of the journey the customer's map should be drawing.
///
/// Published into the tracking session so the customer app can switch legs the
/// instant the driver does, rather than waiting for a booking refresh to tell
/// it the status moved.
enum TrackingPhase {
  /// Driver → pickup. Runs from `driver_en_route` until the trip starts.
  toPickup('to_pickup'),

  /// Driver → drop-off. Runs from `trip_started` to the end of the ride.
  toDropOff('to_dropoff'),

  /// Under way with nowhere to route to — hourly chauffeur hire, which has no
  /// drop-off point because the customer directs the car themselves. The
  /// position is still published; there is simply no second leg to draw.
  inProgress('in_progress');

  const TrackingPhase(this.wireValue);

  final String wireValue;

  /// The leg [trip] is on, from the status the backend last reported.
  static TrackingPhase of(TripV2 trip) {
    if (trip.status != TripStatusV2.tripStarted) return toPickup;
    return trip.hasDropOffPoint ? toDropOff : inProgress;
  }
}

class TrackingService with ChangeNotifier {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  // ---------------------------------------------------------------------------
  // Tuning
  // ---------------------------------------------------------------------------

  /// How often the platform is asked for a fix.
  static const Duration sampleInterval = Duration(seconds: 2);

  /// How far the car must move before a fix is worth publishing, in metres.
  ///
  /// Below this the difference is mostly GPS jitter, and writing it would pay
  /// for a marker that does not visibly move.
  ///
  /// At 50m a car in city traffic publishes every few seconds and one on a
  /// motorway about twice that; the customer app interpolates between the fixes
  /// it receives, so the marker still slides rather than stepping. Raising this
  /// further would start to show as the drawn car lagging the real one.
  static const double _minWriteDistanceMeters = 50;

  /// The longest a published position may go unrefreshed while sharing.
  ///
  /// Keeps `timestamp` moving for a stationary car, so the customer app can
  /// tell a parked driver from a dead feed, at one write a minute.
  static const Duration _heartbeatInterval = Duration(seconds: 60);

  /// How long a start or stop may wait on the network before giving up on
  /// waiting — not on the write.
  ///
  /// Realtime Database queues writes made offline and replays them on
  /// reconnect, so the future can outlive the ride. Since starts and stops are
  /// serialised, waiting on one indefinitely would wedge every later
  /// transition; the local state moves on and the write lands when it can.
  static const Duration _sessionWriteTimeout = Duration(seconds: 8);

  /// How long to wait for the one-off fix taken at start and resume.
  static const Duration _fixTimeout = Duration(seconds: 10);

  static const String _databaseUrl =
      'https://premium-force-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Resolved lazily: Firebase has to be initialised before this is touched.
  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionStreamController =
      StreamController<Position>.broadcast();

  /// Every fix the platform reports, published or not — for anything on-device
  /// that wants the driver's position without paying for a database read.
  Stream<Position> get positionStream => _positionStreamController.stream;

  Position? _lastPosition;
  Position? get currentPosition => _lastPosition;

  /// The last fix actually written, and when: the throttle's memory.
  Position? _lastPublished;
  DateTime? _lastPublishedAt;

  String? _currentBookingId;
  String? get currentBookingId => _currentBookingId;

  /// The leg last written to the session, so a status change that does not move
  /// the map costs no write.
  TrackingPhase? _phase;

  /// When sharing opened — the driver setting off, not the ride beginning.
  DateTime? _startTime;

  /// When the ride itself began, which is what chauffeur hire is billed from.
  ///
  /// Sharing now opens at `driver_en_route`, so measuring booked hours from
  /// [_startTime] would bill the customer for the driver's drive to the pickup.
  /// Null until the trip reaches `trip_started`; a ride cancelled before then
  /// has no billable hours at all.
  DateTime? _rideStartedAt;

  bool get isTracking => _positionStreamSubscription != null;

  /// Whether this exact ride is the one being published.
  bool isTrackingBooking(String bookingId) =>
      isTracking && _currentBookingId == bookingId;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  /// Guards the start/stop path, so two triggers arriving together — a status
  /// update and a refresh, say — cannot open two streams for one ride.
  Future<void> _pending = Future<void>.value();

  // ---------------------------------------------------------------------------
  // Backend-driven lifecycle
  // ---------------------------------------------------------------------------

  /// Bring sharing in line with [trip]'s status as the backend reports it.
  ///
  /// Starts when the driver has set off and is not already being published;
  /// stops when a ride that *was* being published is no longer live. A trip
  /// that is neither is left alone, so a completed booking arriving in a
  /// refresh cannot stop the ride the driver is actually on.
  ///
  /// Silent about permissions: it will not raise dialogs out of a background
  /// refresh. They are asked for with [ensurePermissions] at the point the
  /// driver goes en route, which is the only way to reach
  /// [TripStatusV2.sharesLocation] in the first place.
  Future<void> syncWithTrip(TripV2 trip) {
    return _serialize(() async {
      if (trip.status.sharesLocation) {
        // Both noted before the already-sharing check: the transition that
        // starts the ride arrives while sharing is already open, so returning
        // early first would lose the moment the map has to change legs.
        await _noteRideStart(trip);
        await _notePhase(trip);

        if (isTrackingBooking(trip.id)) return;

        if (!await hasAllPermissions()) {
          return;
        }

        await _start(
          bookingId: trip.id,
          customerId: trip.customerId ?? '',
          driverId: UserLocalStorage.getUserId() ?? '',
          isChauffeur: trip.isChauffeur,
          phase: TrackingPhase.of(trip),
        );

        // Again after starting: relaunching mid-ride opens the session at a
        // trip that is already under way, and the call above ran before there
        // was a session to record it against.
        await _noteRideStart(trip);
        return;
      }

      if (_currentBookingId == trip.id) await _stop();
    });
  }

  /// Record when the ride itself began, once, for the session being published.
  ///
  /// Written as `startTime` because that is what the customer app's chauffeur
  /// meter reads, and what it has always meant: the hire clock, which starts
  /// when the passenger gets in and not when the driver sets off to fetch them.
  /// The moment sharing opened is `sharingStartTime`, kept separate for exactly
  /// that reason.
  ///
  /// Prefers the timeline's own timestamp over the device clock, so a driver
  /// whose app was killed and relaunched mid-ride resumes the same meter rather
  /// than restarting it.
  Future<void> _noteRideStart(TripV2 trip) async {
    if (trip.status != TripStatusV2.tripStarted) return;
    if (_currentBookingId != trip.id || _rideStartedAt != null) return;

    final startedAt = trip.rideStartedAt?.toLocal() ?? DateTime.now();
    _rideStartedAt = startedAt;

    await _writeSession(trip.id, (ref) async {
      await ref.update({
        'startTime': startedAt.toIso8601String(),
        'rideStartedAt': ServerValue.timestamp,
      });
    });
  }

  /// Move the customer's map onto the leg [trip] is now on.
  ///
  /// The two legs are the journey as the customer experiences it: the car
  /// coming to fetch them, then the car carrying them. Starting the trip is
  /// what switches between them, and hourly chauffeur hire never switches —
  /// there is no drop-off to head for.
  ///
  /// A no-op unless the leg actually changed: `driver_arrived` leaves the map
  /// exactly where `driver_en_route` put it, and rewriting it would be a paid
  /// write for no visible difference.
  Future<void> _notePhase(TripV2 trip) async {
    if (_currentBookingId != trip.id) return;

    final phase = TrackingPhase.of(trip);
    if (phase == _phase) return;
    _phase = phase;

    await _writeSession(trip.id, (ref) async {
      await ref.update({'phase': phase.wireValue});
    });
  }

  /// Reconcile against every trip the backend currently calls active.
  ///
  /// The list is authoritative: if none of them is live, whatever is being
  /// published has ended — cancelled by dispatch, completed on another device —
  /// and is stopped.
  Future<void> syncWithActiveTrips(List<TripV2> trips) {
    final live = trips.where((t) => t.status.sharesLocation).firstOrNull;
    if (live != null) return syncWithTrip(live);

    // Decided inside the queue rather than before it: a start may be half done,
    // with the session already open and the position stream not yet attached,
    // and that ride still has to be closed.
    return _serialize(() async {
      if (_currentBookingId == null) return;
      await _stop();
    });
  }

  /// Stop sharing whatever is being shared, e.g. on logout.
  Future<void> stopTracking() => _serialize(_stop);

  /// Run [action] after whatever start or stop is already in flight.
  ///
  /// The returned future is the guarded one: a failed transition is logged and
  /// otherwise absorbed, so it can neither poison the queue for every later
  /// transition nor surface as an unhandled error in the fire-and-forget
  /// callers.
  Future<void> _serialize(Future<void> Function() action) {
    final guarded = _pending.then((_) => action()).catchError((Object e) {});
    _pending = guarded;
    return guarded;
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Whether everything sharing needs is already granted, asking for nothing.
  ///
  /// Background ("always") access is part of it: the phone is in the driver's
  /// pocket for most of a ride, and without it the platform stops the stream as
  /// soon as the app leaves the foreground.
  Future<bool> hasAllPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    return await Geolocator.checkPermission() == LocationPermission.always;
  }

  /// Ask for whatever is still missing, in the order the platforms require.
  ///
  /// Location services first, then foreground access, then — after the
  /// disclosure the stores require — background access. Returns true only when
  /// the full set is granted; every refusal explains itself and offers the
  /// settings screen that can undo it, so the driver is never left at a dead
  /// end.
  Future<bool> ensurePermissions(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;

    // 1. The device's location radio, which no app permission substitutes for.
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (context.mounted) {
        _showErrorDialog(
          context,
          loc.enableLocationServices,
          loc.locationServicesDisabledMessage,
          openLocationSettings: true,
        );
      }
      return false;
    }

    // 2. Foreground access. `deniedForever` can only be undone in settings.
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showErrorDialog(
          context,
          loc.locationBackgroundDisclosureTitle,
          loc.locationPermissionsPermanentlyDenied,
          openAppSettings: true,
        );
      }
      return false;
    }

    if (permission == LocationPermission.denied) return false;

    // 3. Background access, which Android 10+ only grants once the app already
    //    has foreground access and has explained why it wants more.
    if (permission != LocationPermission.always) {
      if (!context.mounted) return false;

      final proceed = await _showBackgroundDisclosureDialog(context);
      if (proceed != true) return false;

      permission = await Geolocator.requestPermission();

      if (permission != LocationPermission.always) {
        // Android sends the driver to settings for "Allow all the time"; no
        // second in-app prompt can grant it.
        if (context.mounted) {
          _showErrorDialog(
            context,
            loc.locationBackgroundDisclosureTitle,
            loc.locationPermissionAlwaysRequired,
            openAppSettings: true,
          );
        }
        return false;
      }
    }

    return true;
  }

  Future<bool?> _showBackgroundDisclosureDialog(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.locationBackgroundDisclosureTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          loc.locationBackgroundDisclosureMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0C0C0),
              foregroundColor: Colors.black,
            ),
            child: Text(loc.allowAllTheTime),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    bool openAppSettings = false,
    bool openLocationSettings = false,
  }) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.ok, style: const TextStyle(color: Colors.grey)),
          ),
          if (openAppSettings || openLocationSettings)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (openLocationSettings) {
                  Geolocator.openLocationSettings();
                } else if (openAppSettings) {
                  Geolocator.openAppSettings();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0C0C0),
                foregroundColor: Colors.black,
              ),
              child: Text(loc.openSettings),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pause / resume
  // ---------------------------------------------------------------------------

  /// Hold publishing without giving up the stream or the session.
  Future<void> pauseTracking({String? bookingId}) async {
    final targetId = bookingId ?? _currentBookingId;
    if (targetId == null || _isPaused) return;

    _isPaused = true;
    await _database.ref('bookings/$targetId/tracking_session').update({
      'isPaused': true,
      'pausedAt': ServerValue.timestamp,
    });
    notifyListeners();
  }

  /// Resume publishing, with an immediate fix so the marker does not sit where
  /// the car was before the pause.
  Future<void> resumeTracking({String? bookingId}) async {
    final targetId = bookingId ?? _currentBookingId;
    if (targetId == null || !_isPaused) return;

    _isPaused = false;
    await _database.ref('bookings/$targetId/tracking_session').update({
      'isPaused': false,
      'resumedAt': ServerValue.timestamp,
    });
    notifyListeners();

    await _publishCurrentPosition(targetId);
  }

  // ---------------------------------------------------------------------------
  // Start / stop
  // ---------------------------------------------------------------------------

  Future<void> _start({
    required String bookingId,
    required String customerId,
    required String driverId,
    required bool isChauffeur,
    required TrackingPhase phase,
  }) async {
    // Another ride may still be publishing; only one can be.
    await _stop();

    _currentBookingId = bookingId;
    _phase = phase;
    _startTime = DateTime.now();
    _rideStartedAt = null;
    _isPaused = false;
    _lastPublished = null;
    _lastPublishedAt = null;

    // Session metadata: one write, when the driver sets off.
    await _writeSession(bookingId, (ref) async {
      await ref.set({
        'bookingId': bookingId,
        'customerId': customerId,
        'driverId': driverId,
        'isActive': true,
        'isChauffeur': isChauffeur,
        // Which leg the customer's map should draw. Normally `to_pickup`; a
        // relaunch mid-ride can open the session already on a later leg.
        'phase': phase.wireValue,
        // When the feed opened — the driver setting off. The hire clock
        // (`startTime`) is written later, by _noteRideStart, so the customer's
        // chauffeur meter does not run through the approach.
        'sharingStartTime': _startTime!.toIso8601String(),
        'startedAt': ServerValue.timestamp,
      });
    });
    notifyListeners();

    // The stream only fires on the next fix, so without this the customer
    // watches an empty map until the car moves.
    await _publishCurrentPosition(bookingId);

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: _locationSettings(),
        ).listen(
          (position) => _onPosition(bookingId, position),
          onError: (Object error) {},
        );
    notifyListeners();
  }

  /// Stop sharing and close the session.
  ///
  /// `isActive: false` is what tells the customer app the ride is over, so its
  /// map can stop drawing and its tracking card can take itself away.
  ///
  /// No hours are computed here. Chauffeur overtime and what it costs are the
  /// backend's to work out from the timeline it already holds; a figure derived
  /// from the driver's device clock could only ever disagree with it.
  Future<void> _stop() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    final bookingId = _currentBookingId;
    if (bookingId == null) {
      notifyListeners();
      return;
    }

    // Session metadata: the second and last write of the ride.
    await _writeSession(
      bookingId,
      (ref) => ref.update({
        'isActive': false,
        'stopTime': DateTime.now().toIso8601String(),
        'stoppedAt': ServerValue.timestamp,
      }),
    );

    _currentBookingId = null;
    _phase = null;
    _startTime = null;
    _rideStartedAt = null;
    _isPaused = false;
    _lastPublished = null;
    _lastPublishedAt = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sampling and publishing
  // ---------------------------------------------------------------------------

  /// Ask the platform for a fix every [sampleInterval], and keep doing it in
  /// the background.
  ///
  /// `distanceFilter: 0` makes the cadence purely time-based; how far the car
  /// moved is [_shouldPublish]'s business, which is about what reaches the
  /// database rather than what the platform reports. Android needs a foreground
  /// service to keep sampling with the screen off, and iOS needs background
  /// location updates together with the `location` background mode.
  LocationSettings _locationSettings() {
    const accuracy = LocationAccuracy.high;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final isArabic = UserLocalStorage.getLanguage() == 'ar';
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: 0,
        intervalDuration: sampleInterval,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: isArabic ? 'رحلة قيد التنفيذ' : 'Ride in progress',
          notificationText: isArabic
              ? 'تتم مشاركة موقعك مع العميل'
              : 'Your location is being shared with the customer',
          notificationChannelName: isArabic ? 'تتبع الرحلة' : 'Ride tracking',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(accuracy: accuracy, distanceFilter: 0);
  }

  void _onPosition(String bookingId, Position position) {
    _lastPosition = position;
    if (!_positionStreamController.isClosed) {
      _positionStreamController.add(position);
    }

    // Still sampling, just not publishing, so a resume has a fresh fix to hand.
    if (_isPaused) return;
    // A stop that raced the last fix must not resurrect the feed.
    if (_currentBookingId != bookingId) return;
    if (!_shouldPublish(position)) return;

    _write(bookingId, position);
  }

  /// Whether [position] is worth a write: moved far enough to be visible, or
  /// stale enough that the customer app should be told the feed is still alive.
  bool _shouldPublish(Position position) {
    final last = _lastPublished;
    final lastAt = _lastPublishedAt;
    if (last == null || lastAt == null) return true;

    final moved = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      position.latitude,
      position.longitude,
    );
    if (moved >= _minWriteDistanceMeters) return true;

    return DateTime.now().difference(lastAt) >= _heartbeatInterval;
  }

  /// Write to this ride's session node, never blocking longer than
  /// [_sessionWriteTimeout] and never throwing.
  ///
  /// A session write that cannot be made now is not worth failing a start or a
  /// stop over: the position feed is what the customer watches, and the pending
  /// write still reaches the database on reconnect.
  Future<void> _writeSession(
    String bookingId,
    Future<void> Function(DatabaseReference ref) write,
  ) async {
    final ref = _database.ref('bookings/$bookingId/tracking_session');
    try {
      await write(ref).timeout(_sessionWriteTimeout);
    } on TimeoutException {
      // Per the doc above: never worth failing a ride start or stop over.
    } catch (e) {
      // Same — the pending write still lands on reconnect.
    }
  }

  /// Read the current fix and publish it, ignoring the throttle.
  ///
  /// For the two moments a stale marker would mislead: the start of a ride, and
  /// a resume.
  Future<void> _publishCurrentPosition(String bookingId) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _fixTimeout,
        ),
      );
      _lastPosition = position;
      if (!_positionStreamController.isClosed) {
        _positionStreamController.add(position);
      }
      if (!_isPaused && _currentBookingId == bookingId) {
        _write(bookingId, position);
      }
    } catch (e) {
      // No fix available right now; the position stream publishes the next one.
    }
  }

  /// The only place a position reaches the database.
  ///
  /// Three fields, overwritten in place — no history is kept, because the
  /// customer app only ever reads the latest one.
  void _write(String bookingId, Position position) {
    _lastPublished = position;
    _lastPublishedAt = DateTime.now();

    _database
        .ref('bookings/$bookingId/driver_location')
        .set({
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': ServerValue.timestamp,
        })
        .catchError((Object error) {
          // Let the next fix retry rather than wait out the heartbeat.
          _lastPublished = null;
          _lastPublishedAt = null;
        });
  }
}
