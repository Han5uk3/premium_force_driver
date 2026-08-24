import 'dart:async';

import 'package:flutter/material.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/services/tracking_service.dart';

/// Shown when a ride is under way but its location is not being published.
///
/// Sharing normally restores itself: killing the app ends it, and the next
/// refresh of the active list reconciles against the backend and starts it
/// again ([TrackingService.syncWithActiveTrips]). That path is deliberately
/// silent about permissions, though — it runs out of background refreshes and
/// must not throw dialogs at the driver — so when the "always" location grant
/// is missing or the location radio is off, it gives up without a word. The
/// driver then carries a passenger while the customer's map shows nothing, and
/// nothing on screen says so.
///
/// This is the visible half of that: it states the problem and offers the one
/// action that can fix it, [TrackingService.ensurePermissions], which *does*
/// raise the dialogs because it is driven by a tap.
///
/// Renders nothing at all when there is no live trip, or when the live trip is
/// already being published — which is the ordinary case.
class SharingRestoreBanner extends StatefulWidget {
  const SharingRestoreBanner({super.key, required this.liveTrip});

  /// The ride currently under way, or null when there is none.
  final TripV2? liveTrip;

  @override
  State<SharingRestoreBanner> createState() => _SharingRestoreBannerState();
}

class _SharingRestoreBannerState extends State<SharingRestoreBanner> {
  bool _isRestoring = false;

  /// Whether enough time has passed to trust that sharing is genuinely off.
  ///
  /// The automatic reconcile runs a moment after the active list loads, so on a
  /// cold start there is a window where a ride is live and not yet published
  /// but is about to be. Showing an alarming banner for that half-second, only
  /// to pull it away, would train drivers to ignore it — so it waits out the
  /// window and appears only if the reconcile really did not fix things.
  bool _graceElapsed = false;
  Timer? _graceTimer;

  static const Duration _grace = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _graceTimer = Timer(_grace, () {
      if (mounted) setState(() => _graceElapsed = true);
    });
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  Future<void> _restore(TripV2 trip) async {
    setState(() => _isRestoring = true);

    final tracking = TrackingService();
    // Asks for whatever is missing, explaining itself and offering the settings
    // screen at each refusal. Returns false if the driver declines, in which
    // case the banner simply stays up.
    final granted = await tracking.ensurePermissions(context);
    if (granted) {
      await tracking.syncWithTrip(trip);
    }

    if (mounted) setState(() => _isRestoring = false);
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.liveTrip;
    if (trip == null || !_graceElapsed) return const SizedBox.shrink();

    // Rebuilds when sharing starts or stops, so the banner takes itself away
    // the moment the feed is running again — including when it was the
    // automatic reconcile, not this button, that fixed it.
    return ListenableBuilder(
      listenable: TrackingService(),
      builder: (context, _) {
        if (TrackingService().isTrackingBooking(trip.id)) {
          return const SizedBox.shrink();
        }

        final loc = AppLocalizations.of(context)!;
        return Padding(
          // Bottom gap only. The dashboard's scroll view already insets its
          // children by 16, so adding horizontal padding here indented this
          // card past the stat cards and the trip card it sits between.
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              // Matches the Cards around it, which are all 16.
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withAlpha(120)),
            ),
            // Stacked rather than a three-across row: the message is a full
            // sentence and the button's label is long in both languages, so
            // side by side they fought each other for width and wrapped into a
            // ragged block. Given its own line, each gets the width it needs.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    // Centred against the title rather than the whole block,
                    // so the icon sits on the line it belongs to.
                    Expanded(
                      child: Text(
                        loc.locationSharingOffTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  loc.locationSharingOffMessage,
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  // Directional, so it sits bottom-left under Arabic and
                  // bottom-right under English without a second layout.
                  alignment: AlignmentDirectional.centerEnd,
                  child: _isRestoring
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.orange,
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: () => _restore(trip),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            backgroundColor: Colors.orange.withAlpha(40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            loc.resumeTracking,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
