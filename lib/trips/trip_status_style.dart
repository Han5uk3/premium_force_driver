import 'package:flutter/material.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';

/// How each v2 trip status is presented, in one place.
///
/// The status drives a badge colour, a label, and the wording of the single
/// action the driver may take next; keeping the three together stops the trip
/// list and the detail screen from drifting apart.
extension TripStatusStyle on TripStatusV2 {
  /// Badge colour — one hue per stage of the ride.
  Color get color => switch (this) {
    TripStatusV2.pendingPayment => Colors.orange,
    TripStatusV2.confirmed => Colors.blueGrey,
    TripStatusV2.driverAssigned => Colors.blue,
    TripStatusV2.driverEnRoute => Colors.indigo,
    TripStatusV2.driverArrived => Colors.teal,
    TripStatusV2.tripStarted => Colors.deepPurple,
    TripStatusV2.completed => Colors.green,
    TripStatusV2.cancelled => Colors.red,
    TripStatusV2.unknown => Colors.grey,
  };

  /// Localised name of the current status.
  String label(AppLocalizations loc) => switch (this) {
    TripStatusV2.pendingPayment => loc.statusPendingPayment,
    TripStatusV2.confirmed => loc.statusConfirmed,
    TripStatusV2.driverAssigned => loc.statusAssigned,
    TripStatusV2.driverEnRoute => loc.statusEnRoute,
    TripStatusV2.driverArrived => loc.statusArrived,
    TripStatusV2.tripStarted => loc.statusInProgress,
    TripStatusV2.completed => loc.statusCompleted,
    TripStatusV2.cancelled => loc.statusCancelled,
    TripStatusV2.unknown => loc.unknown,
  };

  /// Localised label for the one transition the driver may make from here, or
  /// null when there is nothing for them to do.
  String? actionLabel(AppLocalizations loc) => switch (next) {
    TripStatusV2.driverEnRoute => loc.actionStartDriving,
    TripStatusV2.driverArrived => loc.actionArrived,
    TripStatusV2.tripStarted => loc.actionStartTrip,
    TripStatusV2.completed => loc.actionCompleteTrip,
    _ => null,
  };
}
