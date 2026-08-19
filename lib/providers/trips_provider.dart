import 'package:flutter/foundation.dart';
import 'package:premium_force_driver/api/driver_api_v2.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';

/// Loading state of a trip list.
enum TripsStatus { initial, loading, loaded, failure }

/// State for the driver's trips, backed by the v2 driver API.
///
/// The two lists are separate server-side queries rather than slices of one
/// response — `filter=active` and `filter=completed` — so the bucketing rules
/// live with the backend and each list pages independently.
///
/// Status changes go through [advance], which only ever sends
/// [TripStatusV2.next]: the endpoint refuses a skipped step, so the provider
/// never offers one.
class TripsProvider extends ChangeNotifier {
  TripsProvider({DriverApiV2? api}) : _api = api ?? DriverApiV2();

  final DriverApiV2 _api;

  static const int _pageSize = 10;

  TripsStatus _status = TripsStatus.initial;
  TripsStatus get status => _status;

  List<TripV2> _activeTrips = const [];

  /// Trips from assignment through to in-progress, newest pickup first.
  List<TripV2> get activeTrips => _activeTrips;

  List<TripV2> _completedTrips = const [];
  List<TripV2> get completedTrips => _completedTrips;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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
  final Map<TripFilterV2, int> _totalPages = {
    TripFilterV2.active: 1,
    TripFilterV2.completed: 1,
  };
  final Set<TripFilterV2> _loadingMore = {};

  bool isLoadingMore(TripFilterV2 filter) => _loadingMore.contains(filter);

  bool hasMore(TripFilterV2 filter) =>
      (_pages[filter] ?? 1) < (_totalPages[filter] ?? 1);

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

  /// Load the first page of both lists.
  ///
  /// [silent] keeps whatever is on screen while refetching — used when returning
  /// to a screen, so the list does not flash back to a shimmer.
  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      _status = TripsStatus.loading;
      _errorMessage = null;
      notifyListeners();
    }

    final results = await Future.wait([
      _api.getMyTrips(filter: TripFilterV2.active, limit: _pageSize),
      _api.getMyTrips(filter: TripFilterV2.completed, limit: _pageSize),
    ]);

    final active = results[0];
    final completed = results[1];

    if (active.hasData) {
      _activeTrips = active.data!.trips;
      _pages[TripFilterV2.active] = active.data!.page;
      _totalPages[TripFilterV2.active] = active.data!.totalPages;
    }
    if (completed.hasData) {
      _completedTrips = completed.data!.trips;
      _pages[TripFilterV2.completed] = completed.data!.page;
      _totalPages[TripFilterV2.completed] = completed.data!.totalPages;
    }

    // Only a total failure is worth an error screen: if either list arrived, the
    // driver can still work.
    if (active.hasData || completed.hasData) {
      _status = TripsStatus.loaded;
      _errorMessage = null;
    } else if (!silent) {
      _status = TripsStatus.failure;
      _errorMessage = active.message ?? completed.message;
    }

    notifyListeners();
  }

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

      if (filter == TripFilterV2.active) {
        _activeTrips = merged;
      } else {
        _completedTrips = merged;
      }
      _pages[filter] = page.page;
      _totalPages[filter] = page.totalPages;
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
    return updated;
  }

  /// Take the pending action message, clearing it so it is shown only once.
  String? consumeActionMessage() {
    final message = _actionMessage;
    _actionMessage = null;
    return message;
  }

  /// Drop everything held, on logout.
  void reset() {
    _activeTrips = const [];
    _completedTrips = const [];
    _errorMessage = null;
    _actionMessage = null;
    _updatingTripId = null;
    _pages[TripFilterV2.active] = 1;
    _pages[TripFilterV2.completed] = 1;
    _totalPages[TripFilterV2.active] = 1;
    _totalPages[TripFilterV2.completed] = 1;
    _status = TripsStatus.initial;
    notifyListeners();
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
