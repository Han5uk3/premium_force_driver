import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:premium_force_driver/common_widgets/snackbar.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/providers/auth_provider.dart';
import 'package:premium_force_driver/providers/trips_provider.dart';
import 'package:premium_force_driver/services/tracking_service.dart';
import 'package:premium_force_driver/trips/complete_trip_sheet.dart';
import 'package:premium_force_driver/trips/trip_status_style.dart';

/// Everything the driver can *do* to a trip, in one place.
///
/// This used to live privately on the detail screen, which is why the trip list
/// could only ever look at a ride. The controls are now on the card as well, so
/// the confirmation, the on-shift guard, the location permission prompt and the
/// extra-charges sheet all have to run from either surface — and there must be
/// exactly one copy of them, or the two entry points would enforce different
/// rules.
abstract final class TripActions {
  /// Advance [trip] one step along the linear progression.
  ///
  /// Returns the updated trip, or null when the driver backed out or the
  /// endpoint refused. Every path that can refuse says why, on screen.
  static Future<TripV2?> advance(BuildContext context, TripV2 trip) async {
    final loc = AppLocalizations.of(context)!;
    final provider = context.read<TripsProvider>();
    final next = trip.status.next;
    final actionLabel = trip.status.actionLabel(loc);
    if (next == null || actionLabel == null) return null;

    // Going en route is the point of no return for dispatch, and the app's own
    // rules gate it: the driver must be on shift, holding a vehicle.
    if (next == TripStatusV2.driverEnRoute) {
      final blockedReason = _startBlockedReason(context, loc, provider, trip);
      if (blockedReason != null) {
        AnimatedSnackBar.show(context, blockedReason, 'E');
        return null;
      }
    }

    final confirmed = await _confirm(
      context,
      actionLabel,
      trip.status.confirmMessage(loc),
    );
    if (confirmed != true || !context.mounted) return null;

    // Asked for before the status is sent, never after. `driver_en_route` is
    // the transition that opens the location feed, so by the time the backend
    // accepts it the app must already be able to publish — otherwise the
    // customer is told their driver is on the way and shown an empty map. This
    // is also the only moment the driver is looking at the screen and can act
    // on a refusal: nothing later prompts, because the status change itself
    // happens without UI. Refusing therefore abandons the status change too.
    //
    // The later transitions re-check rather than re-prompt: the permission is
    // already granted by then, so this costs nothing and catches the driver who
    // revoked it mid-ride.
    if (next.sharesLocation) {
      final granted = await TrackingService().ensurePermissions(context);
      if (!granted || !context.mounted) return null;
    }

    ExtraChargesInput? extras;
    if (next == TripStatusV2.completed) {
      extras = await CompleteTripSheet.show(context, currency: trip.currency);
      // A dismissed sheet means the driver changed their mind about completing.
      if (extras == null || !context.mounted) return null;
    }

    final updated = await provider.advance(
      trip,
      extraAmount: extras?.amount,
      extraPaymentMethod: extras?.paymentMethod,
      extraNotes: extras?.notes,
    );

    if (!context.mounted) return updated;

    final message = provider.consumeActionMessage();

    if (updated == null) {
      AnimatedSnackBar.show(context, message ?? loc.failedToUpdateStatus, 'E');
      return null;
    }

    // Sharing is not started or stopped from here: TripsProvider.advance has
    // already handed the accepted status to TrackingService, so the feed
    // follows the backend rather than this screen.
    AnimatedSnackBar.show(context, message ?? loc.tripStatusUpdated, 'S');
    return updated;
  }

  /// Open turn-by-turn directions: to the pickup before the passenger is on
  /// board, and to the drop-off once the trip has started.
  static Future<void> openDirections(BuildContext context, TripV2 trip) async {
    final loc = AppLocalizations.of(context)!;
    final position = TrackingService().currentPosition;
    final origin = position != null
        ? '${position.latitude},${position.longitude}'
        : 'Current+Location';

    final headingToDropOff =
        trip.status == TripStatusV2.tripStarted &&
        _hasUsableCoordinates(trip.dropOffLat, trip.dropOffLng);

    final destination = headingToDropOff
        ? '${trip.dropOffLat},${trip.dropOffLng}'
        : _hasUsableCoordinates(trip.pickupLat, trip.pickupLng)
        ? '${trip.pickupLat},${trip.pickupLng}'
        // An airport arrival names a gate rather than a fixed point — the
        // payload sends 0,0 for it — so the address is what maps is given.
        : _encodedAddress(trip);

    if (destination == null) {
      AnimatedSnackBar.show(context, loc.couldNotLaunchMaps, 'E');
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=$origin&destination=$destination',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      AnimatedSnackBar.show(context, loc.couldNotLaunchMaps, 'E');
    }
  }

  /// Whether the trip has anywhere to navigate to at all.
  static bool canOpenDirections(TripV2 trip) {
    if (trip.status == TripStatusV2.tripStarted &&
        _hasUsableCoordinates(trip.dropOffLat, trip.dropOffLng)) {
      return true;
    }
    return _hasUsableCoordinates(trip.pickupLat, trip.pickupLng) ||
        _encodedAddress(trip) != null;
  }

  static Future<void> callCustomer(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Why the driver cannot go en route yet, or null when they can.
  static String? _startBlockedReason(
    BuildContext context,
    AppLocalizations loc,
    TripsProvider provider,
    TripV2 trip,
  ) {
    final driver = context.read<AuthProvider>().driver;

    if (!(driver?.isWorkstarted ?? false)) return loc.goOnlineToStartTrip;
    if (!(driver?.hasActiveVehicle ?? false)) {
      return loc.takeOutVehicleToStartTrip;
    }

    // Only one ride can be under way: the tracking session is keyed by booking,
    // and the customer of the other ride would stop seeing their driver.
    //
    // Two sources, because either alone has a blind spot. The backend's active
    // list is authoritative but can be a refresh behind — a ride started on
    // another device, or seconds ago on this one, may not be in it yet. The
    // tracking service knows what this app is publishing right now, including
    // a session the driver paused: pausing stops the writes, not the ride, so
    // it still blocks. Whichever notices first wins.
    final live = provider.liveTrip;
    if (live != null && live.id != trip.id) return loc.finishActiveTripFirst;

    final tracking = TrackingService();
    final trackedId = tracking.currentBookingId;
    if (tracking.isTracking && trackedId != null && trackedId != trip.id) {
      return loc.finishActiveTripFirst;
    }

    return null;
  }

  static Future<bool?> _confirm(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final loc = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                loc.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC0C0C0),
              ),
              child: Text(
                loc.confirm,
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  /// A 0,0 pair is the backend's "no fixed point", not a spot in the Atlantic.
  static bool _hasUsableCoordinates(double? lat, double? lng) =>
      lat != null && lng != null && !(lat == 0 && lng == 0);

  static String? _encodedAddress(TripV2 trip) {
    final address = trip.pickupAddress?.trim();
    if (address == null || address.isEmpty) return null;
    return Uri.encodeComponent(address);
  }
}
