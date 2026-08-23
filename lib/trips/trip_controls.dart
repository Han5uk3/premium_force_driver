import 'package:flutter/material.dart';

import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/models/v2/trip_v2.dart';
import 'package:premium_force_driver/trips/trip_actions.dart';
import 'package:premium_force_driver/trips/trip_status_style.dart';

/// The ride controls — the one status the driver may advance to, and directions
/// to wherever they are headed next.
///
/// Rendered identically on the card and at the top of the detail screen, so a
/// driver who acts from the list gets the same button, the same wording and the
/// same guards as one who opened the ride.
class TripControls extends StatelessWidget {
  const TripControls({
    super.key,
    required this.trip,
    required this.onAdvance,
    this.isUpdating = false,
    this.isCompact = false,
    this.showDirections = true,
  });

  final TripV2 trip;
  final VoidCallback onAdvance;

  /// Spins the action button and refuses further taps while a status change is
  /// in flight.
  final bool isUpdating;

  /// Card sizing — shorter buttons and smaller type than the detail screen.
  final bool isCompact;

  /// Whether to offer directions alongside the status action.
  ///
  /// False on the detail screen, which carries its own directions button beside
  /// the trip-info heading, next to the addresses it would navigate to.
  final bool showDirections;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final actionLabel = trip.status.actionLabel(loc);
    final canNavigate =
        showDirections &&
        !trip.status.isFinished &&
        TripActions.canOpenDirections(trip);

    // Nothing to advance and nowhere to go: a finished ride, or one dispatch
    // has not handed over yet.
    if (actionLabel == null && !canNavigate) {
      if (trip.status.isFinished || isCompact) return const SizedBox.shrink();
      return Center(
        child: Text(
          loc.waitingForDispatch,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    final verticalPadding = isCompact ? 12.0 : 16.0;
    final fontSize = isCompact ? 13.0 : 15.0;

    final directions = OutlinedButton.icon(
      onPressed: () => TripActions.openDirections(context, trip),
      icon: Icon(Icons.directions, size: isCompact ? 16 : 18),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE4A46B),
        side: const BorderSide(color: Color(0xFFE4A46B)),
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      label: Text(
        loc.getDirections,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
    );

    if (actionLabel == null) {
      return SizedBox(width: double.infinity, child: directions);
    }

    final action = ElevatedButton(
      onPressed: isUpdating ? null : onAdvance,
      style: ElevatedButton.styleFrom(
        backgroundColor: trip.status.color,
        disabledBackgroundColor: trip.status.color.withAlpha(120),
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isUpdating
          ? SizedBox(
              width: isCompact ? 16 : 18,
              height: isCompact ? 16 : 18,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              actionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
    );

    if (!canNavigate) {
      return SizedBox(width: double.infinity, child: action);
    }

    // The action leads, since it is the step the ride is waiting on; directions
    // sit beside it rather than under, so neither pushes the card taller.
    return Row(
      children: [
        Expanded(child: action),
        const SizedBox(width: 10),
        Expanded(child: directions),
      ],
    );
  }
}
