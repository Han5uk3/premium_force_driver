import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/driver_api_v2.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/services/tracking_service.dart';

/// Loading state of a trip list.
enum TripsStatus { initial, loading, loaded, failure }

/// State for the driver's trips, backed by the v2 driver API.
///
/// The two lists are separate server-side queries rather than slices of one
/// response — `filter=active` and `filter=completed` — so the bucketing rules
/// live with the backend and each list loads, pages and fails independently.
/// [refreshFilter] fetches one of them, which is what the trips screen uses to
/// pay only for the tab in front of the driver; [refresh] takes both, for the
/// dashboard and for pushes that could have touched either.
///
/// Status changes go through [advance], which only ever sends
/// [TripStatusV2.next]: the endpoint refuses a skipped step, so the provider
/// never offers one.
///
/// Live location sharing hangs off the same statuses. Every path that learns
/// what the backend now says about a trip — [advance], and each refresh of the
/// active list — hands it to [TrackingService], which starts or stops sharing
/// to match. The provider is the only place that does this, so there is one
/// answer to "is this driver being watched", and it is the server's.
class TripsProvider extends ChangeNotifier {
  TripsProvider({DriverApiV2? api, TrackingService? tracking})
    : _api = api ?? DriverApiV2(),
      _tracking = tracking ?? TrackingService();

  final DriverApiV2 _api;
  final TrackingService _tracking;

  static const int _pageSize = 10;

  /// Loading state per list.
  ///
  /// The two tabs are fetched independently — opening the trips screen loads
  /// only the tab being looked at — so one list being unloaded, in flight or
  /// broken says nothing about the other.
  final Map<TripFilterV2, TripsStatus> _statuses = {
    for (final filter in TripFilterV2.values) filter: TripsStatus.initial,
  };

  TripsStatus statusFor(TripFilterV2 filter) =>
      _statuses[filter] ?? TripsStatus.initial;

  /// Whether [filter] has never been fetched, so a screen showing it should.
  bool needsLoad(TripFilterV2 filter) =>
      statusFor(filter) == TripsStatus.initial;

  List<TripV2> _activeTrips = const [];

  /// Trips from assignment through to in-progress, newest pickup first.
  List<TripV2> get activeTrips => _activeTrips;

  List<TripV2> _completedTrips = const [];
  List<TripV2> get completedTrips => _completedTrips;

  /// Why the last load of each list failed, for the tab showing it.
  final Map<TripFilterV2, String?> _errors = {};

  String? errorFor(TripFilterV2 filter) => _errors[filter];

  /// Message from the last action, for the caller to surface. Cleared by
  /// [consumeActionMessage] so it is shown once and not on every rebuild.
  String? _actionMessage;
  String? get actionMessage => _actionMessage;

  /// Id of the trip whose status change is in flight, so only its button spins.
  String? _updatingTripId;
  String? get updatingTripId => _updatingTripId;

  final Map<TripFilterV2, int> _pages = {
    TripFilterV2.active: 1,
    TripFilterV2.completed: 1,
  };

  /// Whether the last page fetched for each filter said there was another.
  ///
  /// Taken from the response rather than recomputed here, so the one place that
  /// knows how to read — or infer — the endpoint's pagination is
  /// [TripListPage.hasMore].
  final Map<TripFilterV2, bool> _hasMore = {
    TripFilterV2.active: false,
    TripFilterV2.completed: false,
  };

  final Set<TripFilterV2> _loadingMore = {};

  bool isLoadingMore(TripFilterV2 filter) => _loadingMore.contains(filter);

  bool hasMore(TripFilterV2 filter) => _hasMore[filter] ?? false;

  List<TripV2> tripsFor(TripFilterV2 filter) => switch (filter) {
    TripFilterV2.active => _activeTrips,
    TripFilterV2.completed => _completedTrips,
  };

  /// The trip the driver is currently on, if any.
  ///
  /// Only one ride can be under way at a time, so this is what the dashboard's
  /// live card and the location-sharing guard both read.
  TripV2? get liveTrip =>
      _activeTrips.where((t) => t.status.isLive).firstOrNull;

  /// The next trip the driver is expected to start.
  TripV2? get nextTrip =>
      liveTrip ??
      _activeTrips
          .where((t) => t.status == TripStatusV2.driverAssigned)
          .firstOrNull;

  /// Trips assigned but not yet under way — what the driver has coming up.
  List<TripV2> get upcomingTrips =>
      _activeTrips.where((t) => !t.status.isLive).toList();

  /// Trips currently under way. Normally at most one, since only one ride can be
  /// driven at a time.
  List<TripV2> get ongoingTrips =>
      _activeTrips.where((t) => t.status.isLive).toList();

  int get activeCount => _activeTrips.length;
  int get upcomingCount => upcomingTrips.length;
  int get ongoingCount => ongoingTrips.length;
  int get completedCount => _completedTrips.length;

  /// Whether a ride is under way, which blocks starting another.
  bool get hasLiveTrip => liveTrip != null;

  /// Load the first page of one list.
  ///
  /// This is what the trips screen calls: it fetches the tab in front of the
  /// driver and leaves the other alone until they ask for it, rather than
  /// paying for both on every visit.
  ///
  /// [silent] keeps whatever is on screen while refetching — used when
  /// returning to a screen, so the list does not flash back to a shimmer.
  Future<void> refreshFilter(TripFilterV2 filter, {bool silent = false}) async {
    if (!silent) {
      _statuses[filter] = TripsStatus.loading;
      _errors.remove(filter);
      notifyListeners();
    }

    final result = await _api.getMyTrips(filter: filter, limit: _pageSize);

    if (result.hasData) {
      final page = result.data!;
      _setTrips(filter, page.trips);
      _pages[filter] = page.page;
      _hasMore[filter] = page.hasMore;
      _statuses[filter] = TripsStatus.loaded;
      _errors.remove(filter);

      // The freshly-read active list is the backend's word on what is live, so
      // it also settles whether this driver should be sharing location — the
      // path by which sharing resumes after the app was killed mid-ride, and
      // by which it stops when dispatch ended the ride elsewhere.
      if (filter == TripFilterV2.active) {
        unawaited(_tracking.syncWithActiveTrips(_activeTrips));
      }
    } else if (statusFor(filter) != TripsStatus.loaded) {
      // Nothing on screen to fall back on, so the failure has to be shown —
      // even when the caller asked to refresh quietly.
      _statuses[filter] = TripsStatus.failure;
      _errors[filter] = result.message;
    } else {
      debugPrint(
        '🚘 Trips │ ${filter.wireValue} refresh failed: '
        '${result.message}',
      );
    }

    notifyListeners();
  }

  /// Load the first page of both lists, in parallel.
  ///
  /// For screens that read from both — the dashboard's counters and its live
  /// trip card — and for the push handler, which cannot know which list the
  /// notification touched.
  Future<void> refresh({bool silent = false}) => Future.wait([
    for (final filter in TripFilterV2.values)
      refreshFilter(filter, silent: silent),
  ]);

  /// Append the next page of one list, if there is one.
  Future<void> loadMore(TripFilterV2 filter) async {
    if (isLoadingMore(filter) || !hasMore(filter)) return;

    _loadingMore.add(filter);
    notifyListeners();

    final nextPage = (_pages[filter] ?? 1) + 1;
    final result = await _api.getMyTrips(
      filter: filter,
      page: nextPage,
      limit: _pageSize,
    );

    if (result.hasData) {
      final page = result.data!;
      // De-duplicate: a trip changing state between two reads shifts the window,
      // which would otherwise repeat an entry.
      final existing = tripsFor(filter);
      final seen = existing.map((t) => t.id).toSet();
      final merged = [
        ...existing,
        ...page.trips.where((t) => !seen.contains(t.id)),
      ];

      _setTrips(filter, merged);
      _pages[filter] = page.page;
      // A page whose every trip was already held means the window has stopped
      // moving; asking again would loop on the same rows forever.
      _hasMore[filter] = page.hasMore && merged.length > existing.length;
    } else {
      debugPrint('🚘 Trips │ load more failed: ${result.message}');
    }

    _loadingMore.remove(filter);
    notifyListeners();
  }

  /// Re-read one trip and fold it back into the lists.
  ///
  /// Used after the detail screen changes a status, so the list behind it agrees
  /// without a full refresh.
  Future<TripV2?> reloadTrip(String tripId) async {
    final result = await _api.getTripById(tripId);
    if (!result.hasData) {
      debugPrint('🚘 Trips │ reload failed: ${result.message}');
      return null;
    }

    _applyTrip(result.data!);
    notifyListeners();
    return result.data;
  }

  /// Advance [trip] one step along the linear progression.
  ///
  /// Completing a trip is the only transition that carries money: [extraAmount],
  /// [extraPaymentMethod] and [extraNotes] record charges the driver took on the
  /// spot, and the backend adds them to the booking's grand total.
  ///
  /// Returns the updated trip, or null when the endpoint refused — in which case
  /// [actionMessage] holds the reason to show.
  Future<TripV2?> advance(
    TripV2 trip, {
    double? extraAmount,
    ExtraPaymentMethodV2? extraPaymentMethod,
    String? extraNotes,
  }) async {
    final next = trip.status.next;
    if (next == null) {
      _actionMessage = null;
      return null;
    }

    _updatingTripId = trip.id;
    notifyListeners();

    final result = await _api.updateTripStatus(
      tripId: trip.id,
      status: next,
      extraAmount: extraAmount,
      extraPaymentMethod: extraPaymentMethod,
      extraNotes: extraNotes,
    );

    _actionMessage = result.message;

    if (!result.hasData) {
      _updatingTripId = null;
      notifyListeners();
      return null;
    }

    // The status endpoint answers with a trimmed booking — status, extras and
    // the timeline — so the full record is re-read before it replaces what the
    // screens are showing, or the route and passenger details would vanish.
    // The trimmed reply stands in if that read fails: the status change itself
    // already succeeded.
    final refreshed = await _api.getTripById(trip.id);
    final updated = refreshed.hasData ? refreshed.data! : result.data!;

    _updatingTripId = null;
    _applyTrip(updated);
    notifyListeners();

    // The backend has accepted the new status; location sharing follows it.
    // Starting the ride opens the feed, completing or cancelling closes it.
    unawaited(_tracking.syncWithTrip(updated));

    return updated;
  }

  /// Take the pending action message, clearing it so it is shown only once.
  String? consumeActionMessage() {
    final message = _actionMessage;
    _actionMessage = null;
    return message;
  }

  /// Drop everything held, on logout.
  ///
  /// Sharing stops with it: there is no longer a driver to attribute a position
  /// to, and the session has to be closed rather than left open.
  void reset() {
    unawaited(_tracking.stopTracking());
    _activeTrips = const [];
    _completedTrips = const [];
    _errors.clear();
    _actionMessage = null;
    _updatingTripId = null;
    _loadingMore.clear();
    for (final filter in TripFilterV2.values) {
      _pages[filter] = 1;
      _hasMore[filter] = false;
      _statuses[filter] = TripsStatus.initial;
    }
    notifyListeners();
  }

  /// Replace the list behind [filter].
  void _setTrips(TripFilterV2 filter, List<TripV2> trips) {
    switch (filter) {
      case TripFilterV2.active:
        _activeTrips = trips;
      case TripFilterV2.completed:
        _completedTrips = trips;
    }
  }

  /// Put [trip] where its current status belongs.
  ///
  /// A completed trip has to move lists, not just change in place, or it would
  /// linger on the active tab until the next full refresh.
  void _applyTrip(TripV2 trip) {
    final belongsInActive = !trip.status.isFinished;

    final active = List<TripV2>.from(_activeTrips)
      ..removeWhere((t) => t.id == trip.id);
    final completed = List<TripV2>.from(_completedTrips)
      ..removeWhere((t) => t.id == trip.id);

    if (belongsInActive) {
      final index = _activeTrips.indexWhere((t) => t.id == trip.id);
      // Keep its position when it was already listed, so the list does not
      // reorder under the driver's finger.
      active.insert(index >= 0 ? index : active.length, trip);
    } else {
      completed.insert(0, trip);
    }

    _activeTrips = active;
    _completedTrips = completed;
  }
}
