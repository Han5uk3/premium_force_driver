/// How a trip's API-supplied values are rendered — one mapping, shared by the
/// card and the detail screen so the two cannot drift.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_service_type.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';

/// The pickup date and time of a trip, as the driver should see them.
///
/// Sources are preferred in this order:
///
/// 1. `pickupDate` + `pickupTime` — the plain local strings the backend stores.
///    They carry no zone, so they are read as a wall clock and formatted
///    without being shifted.
/// 2. `pickupUTC` — an instant, converted to device time.
/// 3. `pickupLocalTimeFormatted` — the server's own rendering
///    (`"10 Aug 2026, 05:00 PM (AST)"`), split at the last comma and shown
///    verbatim. Last, because it is already in the pickup city's timezone but
///    is not localised.
///
/// With no source at all both halves come back as an em dash.
({String date, String time}) formatTripPickup(BuildContext context, TripV2 trip) {
  final instant = trip.pickupDisplayInstant;

  if (instant != null) {
    final locale = Localizations.localeOf(context).languageCode;
    return (
      date: DateFormat('dd MMM, yyyy', locale).format(instant),
      time: DateFormat('h:mm a', locale).format(instant),
    );
  }

  final formatted = trip.pickupLocalTimeFormatted?.trim();
  if (formatted != null && formatted.isNotEmpty) {
    final separator = formatted.lastIndexOf(',');
    if (separator <= 0) return (date: formatted, time: '');
    return (
      date: formatted.substring(0, separator).trim(),
      time: formatted.substring(separator + 1).trim(),
    );
  }

  return (date: '—', time: '—');
}

/// The pickup on one line, e.g. `"12 Aug, 2026  ·  6:00 PM"`.
String formatTripPickupLine(BuildContext context, TripV2 trip) {
  final pickup = formatTripPickup(context, trip);
  if (pickup.time.isEmpty) return pickup.date;
  return '${pickup.date}  ·  ${pickup.time}';
}

/// Localised product name — "Airport Arrival", "Chauffeur Service", and so on.
///
/// The card used to render the literal word "Service Type" here, which named
/// the field rather than the product.
String tripServiceLabel(AppLocalizations loc, TripV2 trip) {
  return switch (trip.resolvedServiceType) {
    TripServiceType.airportArrival => loc.airportArrival,
    TripServiceType.airportDeparture => loc.airportDeparture,
    TripServiceType.chauffeur => loc.chauffeurService,
    TripServiceType.privateTransfer => loc.privateTransfer,
    // An unrecognised serviceType still has the booked hours to fall back on.
    null => trip.isChauffeur ? loc.chauffeurService : loc.serviceType,
  };
}

/// Booked hours, e.g. `"6 hrs"`, or null when the trip is not hourly hire.
String? tripDurationLabel(AppLocalizations loc, TripV2 trip) {
  final hours = trip.durationHours;
  return hours == null ? null : '$hours ${loc.hrs}';
}
